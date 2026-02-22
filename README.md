# docker-moodle

Dockerized Moodle 5.1 on PHP 8.4-Apache. Requires a separate MariaDB container on a shared Docker network — not included, must be provisioned separately.

## Usage

```bash
cp .env.example .env   # edit values
docker compose up -d --build
```

## Configuration

All settings live in `.env`. See `.env.example` for the full list.

| Variable | Purpose |
|---|---|
| `MOODLE_SITE_URL` | Public URL (`https://moodle.example.com`) |
| `MOODLE_DB_HOST/NAME/USER/PASS/PORT` | MariaDB connection |
| `MOODLE_INSTALL_ADMIN_PASS` | Admin password (install-time only) |
| `MOODLE_INSTALL_ADMIN_EMAIL` | Admin email (install-time only) |

## Plugins

Drop plugins into `plugins/` mirroring Moodle's directory structure, then restart:

```
plugins/mod/customplugin/
plugins/theme/mytheme/
plugins/local/myplugin/
```

No rebuild needed — `entrypoint.sh` copies them in on startup.

## Reverse proxy (Traefik)

To put Moodle behind Traefik with automatic TLS, create a `compose.override.yaml` (gitignored):

```yaml
services:
  moodle:
    networks:
      - traefik
    labels:
      traefik.enable: "true"
      traefik.docker.network: traefik
      traefik.http.routers.moodle.entrypoints: https
      traefik.http.routers.moodle.rule: "Host(`moodle.example.com`)"
      traefik.http.routers.moodle.tls: "true"
      traefik.http.routers.moodle.tls.certresolver: letsencrypt
      traefik.http.services.moodle.loadbalancer.server.port: "80"

networks:
  traefik:
    external: true
```

Replace `moodle.example.com` with your domain. Set `MOODLE_SSL_PROXY=true` and `MOODLE_SITE_URL=https://moodle.example.com` in `.env`. Docker Compose merges the override automatically.

## Database setup

This stack expects a MariaDB container on the `database_net` Docker network. Minimal example — **not production-ready** (no backups, no tuning, no healthchecks):

```bash
docker network create database_net
```

```yaml
# database/compose.yaml
services:
  mariadb:
    image: mariadb:11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: changeme
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - database_net

volumes:
  mariadb-data:
    name: mariadb-data

networks:
  database_net:
    external: true
```

```bash
docker compose -f database/compose.yaml up -d
```
