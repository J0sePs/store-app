#!/usr/bin/env python3
"""Calcula el presupuesto de pods y de memoria del clúster y falla si no cabe.

Lee:
  - los manifiestos de store-gitops (apps/*) con `kubectl kustomize`,
  - los valores de Helm de Argo CD (infra/terraform/argocd/values.yaml),
  - las réplicas de CoreDNS y del controlador EBS CSI (infra/terraform/eks.tf y ebs-csi.tf),
  - el tipo y la cantidad de nodos (infra/terraform/variables.tf).

Los pods y la memoria de los DaemonSets y de los addons de EKS son los valores medidos en el clúster real
tras el apply (constantes de abajo); se revisan con `kubectl get pods -n kube-system` si cambia la versión de EKS.

Uso (necesita PyYAML y kubectl):
  products-service/.venv/bin/python scripts/check-capacity.py
  products-service/.venv/bin/python scripts/check-capacity.py --gitops /ruta/a/store-gitops

Códigos de salida: 0 = cabe, 1 = se supera algún presupuesto, 2 = error de entrada.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    print("Falta PyYAML. Ejecuta el script con products-service/.venv/bin/python", file=sys.stderr)
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parent.parent

# (pods máximos por nodo, memoria asignable aproximada en MiB, CPU asignable en millicores)
INSTANCE_LIMITS: dict[str, tuple[int, int, int]] = {
    "t3.small": (11, 1433, 1930),
    "t3.medium": (17, 3100, 1930),
}

MIN_FREE_PODS = 3  # pods libres que deben quedar para el rolling update de la demo
DEMO_SURGE_PODS = 2  # el frontend y products-service se actualizan a la vez (maxSurge: 1 cada uno)
MAX_MEMORY_FRACTION = 0.70  # tope de memoria solicitada sobre la asignable

# Memoria solicitada (MiB) de los addons y DaemonSets de EKS (estimación de sus valores por defecto)
# Valores medidos en el clúster real tras el apply (kubectl get pods -n kube-system, EKS 1.36):
# nombre -> (memoria solicitada en MiB, CPU solicitada en m) por pod
DAEMONSETS_PER_NODE = {"aws-node": (0, 50), "kube-proxy": (0, 100), "ebs-csi-node": (104, 30)}
COREDNS_MEMORY_MIB = 70
EBS_CSI_CONTROLLER_MEMORY_MIB = 232  # 6 contenedores
EBS_CSI_CONTROLLER_PODS_PER_REPLICA = 1


class InputError(Exception):
    """Entrada inválida o archivo ausente."""


@dataclass
class Pod:
    name: str
    memory_mib: float
    cpu_m: float
    node_fixed: bool = False  # DaemonSet: ya está en cada nodo


@dataclass
class Report:
    pods: list[Pod] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def parse_memory(value: str | int | float) -> float:
    """Convierte una cantidad de Kubernetes ('128Mi', '1Gi', '256M') a MiB."""
    text = str(value).strip()
    match = re.fullmatch(r"([0-9.]+)([A-Za-z]*)", text)
    if not match:
        raise InputError(f"Cantidad de memoria no válida: {value!r}")
    number, unit = float(match.group(1)), match.group(2)
    factors = {
        "": 1 / 1048576,
        "Ki": 1 / 1024,
        "Mi": 1,
        "Gi": 1024,
        "Ti": 1048576,
        "K": 1000 / 1048576,
        "M": 1000000 / 1048576,
        "G": 1e9 / 1048576,
    }
    if unit not in factors:
        raise InputError(f"Unidad de memoria no soportada: {value!r}")
    return number * factors[unit]


def parse_cpu(value: str | int | float) -> float:
    """Convierte una cantidad de CPU ('50m', '1') a millicores."""
    text = str(value).strip()
    return float(text[:-1]) if text.endswith("m") else float(text) * 1000


def read_text(path: Path) -> str:
    if not path.is_file():
        raise InputError(f"No existe el archivo: {path}")
    return path.read_text()


def terraform_default(variables_tf: str, name: str) -> str:
    """Valor por defecto de una variable de Terraform (primer literal tras `default =`)."""
    block = re.search(rf'variable "{re.escape(name)}" \{{(.*?)\n\}}', variables_tf, re.S)
    if not block:
        raise InputError(f"No se encontró la variable {name} en variables.tf")
    default = re.search(r"default\s*=\s*(.+)", block.group(1))
    if not default:
        raise InputError(f"La variable {name} no tiene valor por defecto")
    return default.group(1).strip()


def replica_count(tf_text: str, label: str) -> int:
    """Lee `replicaCount = N` de la configuración de un addon en un archivo de Terraform."""
    match = re.search(r"replicaCount\s*=\s*(\d+)", tf_text)
    if not match:
        raise InputError(f"No se encontró replicaCount para {label}")
    return int(match.group(1))


def kustomize(directory: Path) -> list[dict]:
    try:
        out = subprocess.run(
            ["kubectl", "kustomize", str(directory)], capture_output=True, text=True, check=True
        ).stdout
    except FileNotFoundError as exc:
        raise InputError("Falta kubectl (se usa 'kubectl kustomize')") from exc
    except subprocess.CalledProcessError as exc:
        raise InputError(f"kubectl kustomize falló en {directory}: {exc.stderr.strip()}") from exc
    return [doc for doc in yaml.safe_load_all(out) if doc]


def workload_pods(doc: dict, report: Report, origin: str) -> list[Pod]:
    """Pods de un Deployment o StatefulSet; registra errores de requests/limits."""
    replicas = int(doc["spec"].get("replicas", 1))
    name = doc["metadata"]["name"]
    memory = cpu = 0.0
    for container in doc["spec"]["template"]["spec"]["containers"]:
        resources = container.get("resources", {})
        requests, limits = resources.get("requests", {}), resources.get("limits", {})
        where = f"{origin}/{name}/{container['name']}"
        if not requests.get("memory") or not requests.get("cpu") or not limits.get("memory") or not limits.get("cpu"):
            report.errors.append(f"{where}: faltan requests o limits de cpu y memory")
            continue
        req_mem, lim_mem = parse_memory(requests["memory"]), parse_memory(limits["memory"])
        if lim_mem < req_mem:
            report.errors.append(
                f"{where}: el limit de memoria ({limits['memory']}) es menor que el request ({requests['memory']})"
            )
        memory += req_mem
        cpu += parse_cpu(requests["cpu"])
    return [Pod(name=f"{name}-{i}" if replicas > 1 else name, memory_mib=memory, cpu_m=cpu) for i in range(replicas)]


def argocd_pods(values: dict, report: Report) -> list[Pod]:
    """Pods de larga vida de Argo CD según sus valores de Helm (los valores por defecto del chart son 1 réplica)."""
    pods: list[Pod] = []

    def section(key: str) -> dict:
        return values.get(key) or {}

    def add(name: str, replicas: int, resources: dict) -> None:
        requests, limits = resources.get("requests", {}), resources.get("limits", {})
        if replicas > 0 and not (
            requests.get("memory") and requests.get("cpu") and limits.get("memory") and limits.get("cpu")
        ):
            report.errors.append(f"argocd/{name}: faltan requests o limits de cpu y memory en values.yaml")
            return
        for i in range(replicas):
            mem = parse_memory(requests["memory"]) if requests.get("memory") else 0.0
            cpu = parse_cpu(requests["cpu"]) if requests.get("cpu") else 0.0
            pods.append(Pod(name=f"argocd-{name}" + (f"-{i}" if replicas > 1 else ""), memory_mib=mem, cpu_m=cpu))
            if limits.get("memory") and parse_memory(limits["memory"]) < mem:
                report.errors.append(f"argocd/{name}: el limit de memoria es menor que el request")

    add(
        "application-controller",
        int(section("controller").get("replicas", 1)),
        section("controller").get("resources", {}),
    )
    add("repo-server", int(section("repoServer").get("replicas", 1)), section("repoServer").get("resources", {}))
    add("server", int(section("server").get("replicas", 1)), section("server").get("resources", {}))
    if section("redis").get("enabled", True):
        add("redis", 1, section("redis").get("resources", {}))
    if section("dex").get("enabled", True):
        add("dex", 1, section("dex").get("resources", {}))
    if section("notifications").get("enabled", True):
        add("notifications", 1, section("notifications").get("resources", {}))
    add(
        "applicationset",
        int(section("applicationSet").get("replicas", 1)),
        section("applicationSet").get("resources", {}),
    )
    return pods


def build_report(
    gitops: Path, values_file: Path, terraform_dir: Path, nodes_override: int | None
) -> tuple[Report, int, int, int, int, str]:
    variables = read_text(terraform_dir / "variables.tf")
    instance_type = terraform_default(variables, "node_instance_types").strip("[]").split(",")[0].strip().strip('"')
    if instance_type not in INSTANCE_LIMITS:
        raise InputError(f"Tipo de instancia sin datos de capacidad: {instance_type}. Añádelo a INSTANCE_LIMITS")
    max_pods, alloc_mem, alloc_cpu = INSTANCE_LIMITS[instance_type]
    nodes = nodes_override or int(terraform_default(variables, "node_desired_size"))

    report = Report()
    # DaemonSets: uno por nodo
    for name, (mem, cpu) in DAEMONSETS_PER_NODE.items():
        for n in range(nodes):
            report.pods.append(Pod(name=f"{name}@nodo{n + 1}", memory_mib=mem, cpu_m=cpu, node_fixed=True))
    # Addons de EKS configurados en Terraform
    coredns = replica_count(read_text(terraform_dir / "eks.tf"), "coredns")
    ebs = replica_count(read_text(terraform_dir / "ebs-csi.tf"), "el controlador EBS CSI")
    report.pods += [Pod(name=f"coredns-{i}", memory_mib=COREDNS_MEMORY_MIB, cpu_m=100) for i in range(coredns)]
    report.pods += [
        Pod(name=f"ebs-csi-controller-{i}", memory_mib=EBS_CSI_CONTROLLER_MEMORY_MIB, cpu_m=60)
        for i in range(ebs * EBS_CSI_CONTROLLER_PODS_PER_REPLICA)
    ]
    # Argo CD
    report.pods += argocd_pods(yaml.safe_load(read_text(values_file)) or {}, report)
    # Aplicación (store-gitops)
    apps = sorted((gitops / "apps").glob("*/kustomization.yaml"))
    if not apps:
        raise InputError(f"No hay apps/*/kustomization.yaml en {gitops}")
    for kz in apps:
        for doc in kustomize(kz.parent):
            if doc["kind"] in ("Deployment", "StatefulSet"):
                report.pods += workload_pods(doc, report, kz.parent.name)
    return report, nodes, max_pods, alloc_mem, alloc_cpu, instance_type


def place(pods: list[Pod], nodes: int, max_pods: int) -> list[list[Pod]]:
    """Reparto de ejemplo: DaemonSets en cada nodo y el resto, de mayor a menor memoria, en el nodo con menos."""
    layout: list[list[Pod]] = [[] for _ in range(nodes)]
    for pod in (p for p in pods if p.node_fixed):
        layout[int(pod.name.rsplit("nodo", 1)[1]) - 1].append(pod)
    for pod in sorted((p for p in pods if not p.node_fixed), key=lambda p: -p.memory_mib):
        candidates = [n for n in layout if len(n) < max_pods]
        if not candidates:
            return layout  # no cabe: el total ya lo señala
        min(candidates, key=lambda n: sum(p.memory_mib for p in n)).append(pod)
    return layout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--gitops", type=Path, default=REPO_ROOT.parent / "store-gitops", help="ruta del repositorio store-gitops"
    )
    parser.add_argument("--argocd-values", type=Path, default=REPO_ROOT / "infra/terraform/argocd/values.yaml")
    parser.add_argument("--terraform-dir", type=Path, default=REPO_ROOT / "infra/terraform")
    parser.add_argument(
        "--nodes", type=int, default=None, help="número de nodos (por defecto, node_desired_size de Terraform)"
    )
    args = parser.parse_args()

    try:
        report, nodes, max_pods, alloc_mem, alloc_cpu, instance_type = build_report(
            args.gitops, args.argocd_values, args.terraform_dir, args.nodes
        )
    except InputError as exc:
        print(f"ERROR de entrada: {exc}", file=sys.stderr)
        return 2

    total_pods = len(report.pods)
    capacity = nodes * max_pods
    free = capacity - total_pods
    free_after_surge = free - DEMO_SURGE_PODS
    memory = sum(p.memory_mib for p in report.pods)
    cpu = sum(p.cpu_m for p in report.pods)
    alloc_total = nodes * alloc_mem
    memory_limit = alloc_total * MAX_MEMORY_FRACTION

    print(
        f"Capacidad: {nodes} nodos {instance_type} "
        f"({max_pods} pods, {alloc_mem} MiB y {alloc_cpu}m asignables por nodo)\n"
    )
    groups: dict[str, list[Pod]] = {
        "DaemonSets (1 por nodo)": [],
        "kube-system (coredns, ebs-csi-controller)": [],
        "Argo CD": [],
        "Aplicación (store)": [],
    }
    for pod in report.pods:
        key = (
            "DaemonSets (1 por nodo)"
            if pod.node_fixed
            else "kube-system (coredns, ebs-csi-controller)"
            if pod.name.startswith(("coredns", "ebs-csi"))
            else "Argo CD"
            if pod.name.startswith("argocd")
            else "Aplicación (store)"
        )
        groups[key].append(pod)
    print(f"{'Grupo':44} {'Pods':>5} {'Memoria (MiB)':>14} {'CPU (m)':>8}")
    for name, pods in groups.items():
        print(f"{name:44} {len(pods):>5} {sum(p.memory_mib for p in pods):>14.0f} {sum(p.cpu_m for p in pods):>8.0f}")
    print(f"{'TOTAL':44} {total_pods:>5} {memory:>14.0f} {cpu:>8.0f}\n")

    print("Reparto de ejemplo por nodo (el scheduler decide el real):")
    for i, node in enumerate(place(report.pods, nodes, max_pods), start=1):
        node_mem = sum(p.memory_mib for p in node)
        print(
            f"  nodo {i}: {len(node):>2} de {max_pods} pods | "
            f"{node_mem:>6.0f} de {alloc_mem} MiB ({node_mem / alloc_mem:5.0%}) | "
            + ", ".join(p.name.split("@")[0] for p in node)
        )

    print(
        f"\nPods: {total_pods} de {capacity} -> libres {free}; con el rolling update de la demo "
        f"(+{DEMO_SURGE_PODS}) libres {free_after_surge} (mínimo {MIN_FREE_PODS})"
    )
    print(
        f"Memoria solicitada: {memory:.0f} MiB de {alloc_total} MiB asignables = {memory / alloc_total:.0%} "
        f"(tope {MAX_MEMORY_FRACTION:.0%} = {memory_limit:.0f} MiB)"
    )
    print(
        f"CPU solicitada: {cpu:.0f}m de {nodes * alloc_cpu}m asignables = {cpu / (nodes * alloc_cpu):.0%} (informativo)"
    )

    errors = list(report.errors)
    if free_after_surge < MIN_FREE_PODS:
        errors.append(
            f"Quedan {free_after_surge} pods libres tras el rolling update de la demo; el mínimo es {MIN_FREE_PODS}"
        )
    if memory > memory_limit:
        errors.append(
            f"Los requests de memoria ({memory:.0f} MiB) superan el {MAX_MEMORY_FRACTION:.0%} "
            f"de lo asignable ({memory_limit:.0f} MiB)"
        )
    if errors:
        print("\nSE SUPERA EL PRESUPUESTO:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("\nOK: el sistema cabe en el clúster")
    return 0


if __name__ == "__main__":
    sys.exit(main())
