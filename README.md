# docker-moodle

Dockerized Moodle 5.1 on PHP 8.4-Apache. Connects to an external MariaDB and optionally sits behind a reverse proxy (e.g. Traefik).

## Prerequisites

A MariaDB instance must be running and reachable via Docker networking before starting Moodle. This stack does **not** include a database — provision one separately on the `database_net` network.

Minimal example (no backups — add your own for production):

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

## Quick start

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

