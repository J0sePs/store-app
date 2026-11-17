# Etapa 1: compila la SPA con Node
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# La versión se fija al construir la imagen (CI pasará el SHA corto) y se publica en /version.json
ARG APP_VERSION=dev
RUN echo "$APP_VERSION" | grep -Eq '^[A-Za-z0-9._-]+$' \
    || { echo "APP_VERSION inválida: solo se permiten letras, números, punto, guion y guion bajo" >&2; exit 1; } \
    && printf '{"version":"%s"}\n' "$APP_VERSION" > dist/frontend/browser/version.json

# Etapa 2: nginx sin privilegios (usuario nginx, puerto 8080)
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY proxy_params.inc /etc/nginx/conf.d/proxy_params.inc
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html
USER 101
EXPOSE 8080
