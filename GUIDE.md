# Inception — Full Project Guide

This document explains every file that was created, why it exists, and how all the pieces connect together.

---

## Table of Contents

- [Inception — Full Project Guide](#inception--full-project-guide)
  - [Table of Contents](#table-of-contents)
  - [1. Big picture](#1-big-picture)
  - [2. Directory structure](#2-directory-structure)
  - [3. The Makefile](#3-the-makefile)
    - [What each target does](#what-each-target-does)
    - [Why `make setup` creates the host directories first](#why-make-setup-creates-the-host-directories-first)
  - [4. Secrets](#4-secrets)
    - [How Docker secrets work](#how-docker-secrets-work)
    - [The three secret files](#the-three-secret-files)
  - [5. The .env file](#5-the-env-file)
  - [6. docker-compose.yml](#6-docker-composeyml)
    - [Services](#services)
    - [Volumes](#volumes)
    - [Network](#network)
    - [Secrets block](#secrets-block)
  - [7. NGINX container](#7-nginx-container)
    - [Dockerfile](#dockerfile)
    - [conf/nginx.conf](#confnginxconf)
  - [8. MariaDB container](#8-mariadb-container)
    - [Dockerfile](#dockerfile-1)
    - [conf/50-server.cnf](#conf50-servercnf)
    - [tools/db-setup.sh (the init script)](#toolsdb-setupsh-the-init-script)
  - [9. WordPress container](#9-wordpress-container)
    - [Dockerfile](#dockerfile-2)
    - [tools/wp-setup.sh (the init script)](#toolswp-setupsh-the-init-script)
  - [10. Data flow — request to response](#10-data-flow--request-to-response)
  - [11. Startup order and dependencies](#11-startup-order-and-dependencies)
  - [12. Rules compliance checklist](#12-rules-compliance-checklist)

---

## 1. Big picture

```
Browser
  │  HTTPS :443
  ▼
┌─────────────────────────────────────────┐
│  Docker bridge network: "inception"     │
│                                         │
│  ┌──────────────────────┐               │
│  │  NGINX (port 443)    │               │
│  │  TLSv1.2 / TLSv1.3  │               │
│  └──────────┬───────────┘               │
│             │ FastCGI (port 9000)       │
│  ┌──────────▼───────────┐               │
│  │  WordPress + php-fpm │               │
│  └──────────┬───────────┘               │
│             │ MySQL protocol (port 3306)│
│  ┌──────────▼───────────┐               │
│  │  MariaDB             │               │
│  └──────────────────────┘               │
└─────────────────────────────────────────┘

Named volumes (data survives container restarts):
  wordpress  →  /home/joafaust/data/wordpress   (PHP files + uploads)
  mariadb    →  /home/joafaust/data/mariadb     (database files)
```

The **only** entry point from the outside world is **NGINX on port 443**.  
No other port is published to the host.

---

## 2. Directory structure

```
Inception/                        ← git repository root
│
├── Makefile                      ← single command to build & start everything
├── .gitignore                    ← keeps secrets OUT of git
├── README.md                     ← quick-start cheatsheet
├── GUIDE.md                      ← this file
│
├── secrets/                      ← NEVER committed to git
│   ├── credentials.txt           ← WP admin password (line 1) + WP user password (line 2)
│   ├── db_password.txt           ← MariaDB application-user password
│   └── db_root_password.txt      ← MariaDB root password
│
└── srcs/                         ← everything Docker-related
    ├── .env                      ← non-secret variables (domain name, usernames…)
    ├── docker-compose.yml        ← declares all services, volumes, network, secrets
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── .dockerignore
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf
        │   ├── tools/db-setup.sh
        │   └── .dockerignore
        └── wordpress/
            ├── Dockerfile
            ├── tools/wp-setup.sh
            └── .dockerignore
```

---

## 3. The Makefile

**File:** `Makefile` (project root)

The subject requires a Makefile at the root that builds and starts everything with a single command.

```makefile
all: setup
    docker compose -f srcs/docker-compose.yml up -d --build
```

### What each target does

| Target | What happens |
|--------|-------------|
| `make` (= `make all`) | Creates `/home/joafaust/data/{wordpress,mariadb}` on the host, then builds all images and starts all containers in detached mode |
| `make down` | Stops and removes containers (volumes are kept) |
| `make stop` | Pauses containers without removing them |
| `make clean` | Removes containers + volumes + images + host data directories |
| `make fclean` | Same as clean (alias) |
| `make re` | Full clean then full rebuild — use after changing a Dockerfile |
| `make logs` | Follows combined log output from all three containers |
| `make ps` | Shows running containers and their status |

### Why `make setup` creates the host directories first

Docker named volumes with `driver: local` and `o: bind` require the target directory to already exist on the host before the container starts, otherwise Docker throws a permission error. The Makefile handles this automatically with `mkdir -p`.

---

## 4. Secrets

**Directory:** `secrets/`  
**Git status:** ignored via `.gitignore` — never committed

The subject forbids putting passwords in Dockerfiles or committing them to git. The solution is **Docker secrets**.

### How Docker secrets work

1. Each secret is a plain-text file on the host (inside `secrets/`).
2. `docker-compose.yml` declares each file as a named secret.
3. Each service that needs a secret lists it under `secrets:`.
4. At runtime Docker mounts each secret as a read-only file at `/run/secrets/<name>` inside the container.
5. The entrypoint scripts read the value with `cat /run/secrets/<name>`.

### The three secret files

| File | Used by | Contains |
|------|---------|----------|
| `db_password.txt` | MariaDB + WordPress | Password for the `wpuser` database account |
| `db_root_password.txt` | MariaDB | Password for the MariaDB `root` account |
| `credentials.txt` | WordPress | Line 1 = WP admin password, Line 2 = WP regular-user password |

**Change all placeholder values before the first `make`.**

---

## 5. The .env file

**File:** `srcs/.env`  
**Git status:** ignored — never committed

Contains non-secret configuration that is injected into containers via `env_file:` in docker-compose.

```ini
DOMAIN_NAME=joafaust.42.fr    # must match your login

MYSQL_DATABASE=wordpress       # DB name created by MariaDB init script
MYSQL_USER=wpuser              # DB user created by MariaDB init script

WP_ADMIN_USER=joafaust42       # MUST NOT contain "admin" or "administrator"
WP_ADMIN_EMAIL=admin@joafaust.42.fr

WP_USER=joafaust
WP_USER_EMAIL=user@joafaust.42.fr
```

These variables land in the environment of the `wordpress` and `mariadb` containers. The entrypoint scripts read them with `$VARIABLE_NAME`.

---

## 6. docker-compose.yml

**File:** `srcs/docker-compose.yml`

This is the central orchestration file. It defines:

### Services

Three services, one per container:

```
nginx      depends_on → wordpress
wordpress  depends_on → mariadb
mariadb    (no dependencies)
```

Each service has:
- `build:` pointing to the directory that holds its `Dockerfile` — images are built locally, nothing is pulled from Docker Hub.
- `image:` with the same name as the service (project requirement).
- `container_name:` same as the service.
- `restart: unless-stopped` — containers restart automatically after a crash.
- `networks: [inception]` — all three are on the same private bridge.

### Volumes

```yaml
volumes:
  wordpress:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/joafaust/data/wordpress
  mariadb:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/joafaust/data/mariadb
```

These are **named volumes** (required by the subject — bind mounts are forbidden).  
`driver_opts` with `o: bind` tells Docker to store the data in a specific host path. The data survives container restarts and even `docker compose down`.

### Network

```yaml
networks:
  inception:
    driver: bridge
```

A single private bridge. Containers resolve each other by service name (e.g., WordPress connects to MariaDB using the hostname `mariadb`). `network: host` and `--link` are both forbidden by the subject.

### Secrets block

```yaml
secrets:
  db_password:
    file: ../secrets/db_password.txt
  ...
```

Paths are relative to the `docker-compose.yml` file, so `../secrets/` points to `Inception/secrets/`.

---

## 7. NGINX container

**Files:** `srcs/requirements/nginx/`

### Dockerfile

```
FROM alpine:3.20
RUN apk add nginx openssl
RUN openssl req -x509 ...   # generates self-signed TLS cert at build time
COPY conf/nginx.conf ...
CMD ["nginx", "-g", "daemon off;"]
```

Key points:
- Base image is **Alpine 3.20** (penultimate stable at time of writing — not `latest`).
- `openssl` generates a self-signed certificate during the image build. In a real deployment you would replace this with a cert from Let's Encrypt or your CA.
- `daemon off;` makes nginx run in the **foreground** as PID 1. Without this nginx would fork into the background and the container would immediately exit. No `tail -f` or infinite loops are used.

### conf/nginx.conf

```nginx
server {
    listen      443 ssl;
    ssl_protocols  TLSv1.2 TLSv1.3;   # only these two, as required
    ssl_ciphers    HIGH:!aNULL:!MD5;

    location / {
        try_files $uri $uri/ /index.php?$args;   # WordPress pretty URLs
    }

    location ~ \.php$ {
        fastcgi_pass  wordpress:9000;            # php-fpm in the wordpress container
        ...
    }
}
```

NGINX does **not** serve PHP itself. PHP requests are forwarded via **FastCGI** to the `wordpress` container on port 9000. Both containers share the `wordpress` named volume so NGINX can serve static files (images, CSS, JS) directly and only sends `.php` files to php-fpm.

Port 80 is intentionally not exposed — the subject says port 443 is the only entry point.

---

## 8. MariaDB container

**Files:** `srcs/requirements/mariadb/`

### Dockerfile

```
FROM alpine:3.20
RUN apk add mariadb mariadb-client
COPY conf/50-server.cnf /etc/my.cnf.d/
COPY tools/db-setup.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/db-setup.sh"]
```

The container starts via `db-setup.sh`. The script ends with `exec mysqld --user=mysql`, which replaces the shell with the MariaDB daemon — so **mysqld is PID 1**.

### conf/50-server.cnf

A minimal MariaDB server config. The important setting is:

```ini
bind-address = 0.0.0.0
```

Without this MariaDB only listens on `127.0.0.1` (localhost) and the WordPress container cannot reach it.

### tools/db-setup.sh (the init script)

```sh
# 1. Read passwords from Docker secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

# 2. First-run check: only initialise if the mysql system DB doesn't exist yet
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db ...      # creates system tables
    mysqld --bootstrap <<EOF  # runs SQL without starting the full daemon
        CREATE DATABASE wordpress;
        CREATE USER 'wpuser'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
        ...
    EOF
fi

# 3. Start the real server
exec mysqld --user=mysql
```

The `if` guard is essential: on every restart after the first, `/var/lib/mysql/mysql` already exists (on the named volume), so the init block is skipped and the server just starts up normally.

---

## 9. WordPress container

**Files:** `srcs/requirements/wordpress/`

### Dockerfile

```
FROM alpine:3.20
RUN apk add php82 php82-fpm php82-mysqli ... wget
RUN ln -sf /usr/bin/php82 /usr/bin/php     # WP-CLI needs 'php' in PATH
RUN sed -i 's/listen = .*/listen = 9000/'  # php-fpm listens on all interfaces
RUN wget .../wp-cli.phar -O /usr/local/bin/wp  # WP-CLI for automated install
COPY tools/wp-setup.sh ...
ENTRYPOINT ["/usr/local/bin/wp-setup.sh"]
```

**WP-CLI** is a command-line tool for WordPress. It lets the setup script install WordPress, create the config file, and add users — all non-interactively.

php-fpm is configured to listen on `0.0.0.0:9000` so that NGINX (in a separate container) can reach it. `clear_env = no` ensures the environment variables from `.env` are passed through to PHP workers.

### tools/wp-setup.sh (the init script)

```sh
# 1. Read passwords from Docker secrets
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASS=$(head -n 1 /run/secrets/credentials)
WP_USER_PASS=$(tail  -n 1 /run/secrets/credentials)

# 2. First-run check
if [ ! -f "/var/www/html/wp-config.php" ]; then
    wp core download ...             # download WordPress files
    wp config create \
        --dbhost=mariadb \           # hostname = service name on the Docker network
        --dbpass="${DB_PASSWORD}" \  # from secret, never hardcoded
        ...
    # Wait for MariaDB to be ready before trying to install
    until wp db check ...; do sleep 2; done

    wp core install \
        --admin_user="${WP_ADMIN_USER}" \   # from .env  (not "admin")
        --admin_password="${WP_ADMIN_PASS}" \  # from secret
        ...

    wp user create "${WP_USER}" ... --role=author  # second non-admin user
fi

# 3. Start php-fpm as PID 1
exec php-fpm82 -F
```

The `-F` flag runs php-fpm in the foreground. Same principle as nginx `daemon off;` — keeps the process as PID 1.

---

## 10. Data flow — request to response

1. **Browser** sends an HTTPS request to `joafaust.42.fr:443`.
2. **NGINX** terminates TLS (decrypts the request) using the certificate built into the image.
3. If the URL ends in `.php` (or WordPress's front controller `index.php`), NGINX forwards it to **php-fpm** in the WordPress container via FastCGI on port 9000.
4. **php-fpm** executes the PHP code. WordPress needs to read/write the database, so it opens a TCP connection to **MariaDB** on port 3306 (using the hostname `mariadb`, resolved by Docker's internal DNS).
5. MariaDB returns query results. WordPress builds the HTML page.
6. php-fpm sends the HTML back to NGINX via FastCGI.
7. NGINX wraps it in an HTTPS response and sends it to the browser.

Static files (images, CSS, JS) are served directly by NGINX without involving php-fpm.

---

## 11. Startup order and dependencies

```
docker compose up
  │
  ├─ starts mariadb first (no depends_on)
  │     └─ db-setup.sh runs; mysqld starts and becomes PID 1
  │
  ├─ starts wordpress after mariadb (depends_on: mariadb)
  │     └─ wp-setup.sh runs
  │          └─ polls "wp db check" in a loop until MariaDB accepts connections
  │          └─ installs WordPress, creates users
  │          └─ exec php-fpm82 -F  →  php-fpm is now PID 1
  │
  └─ starts nginx after wordpress (depends_on: wordpress)
        └─ nginx -g "daemon off;"  →  nginx is PID 1
```

`depends_on` only guarantees **start order**, not that a service is fully ready. That's why `wp-setup.sh` has a polling loop waiting for MariaDB to actually accept connections before running `wp core install`.

---

## 12. Rules compliance checklist

| Subject rule | Implementation |
|---|---|
| Virtual Machine | You run this on your VM — nothing here prevents that |
| All config in `srcs/` | `srcs/docker-compose.yml`, `srcs/.env`, `srcs/requirements/` |
| Makefile at root | `Makefile` — calls `docker compose -f srcs/docker-compose.yml` |
| Build images with docker-compose | `up --build` in Makefile; no pre-built images pulled |
| NGINX with TLSv1.2/1.3 only | `ssl_protocols TLSv1.2 TLSv1.3;` in nginx.conf |
| WordPress + php-fpm only (no nginx) | WordPress container runs only php-fpm82 |
| MariaDB only (no nginx) | MariaDB container runs only mysqld |
| Named volumes for WP files + DB | `driver: local` volumes in docker-compose |
| Volumes stored in `/home/joafaust/data` | `device:` paths in volume driver_opts |
| Docker network declared | `inception` bridge in docker-compose |
| Containers restart on crash | `restart: unless-stopped` on every service |
| No `tail -f` / infinite loops | All entrypoints end with `exec <daemon>` |
| No `network: host` or `--link` | Custom bridge only |
| Two WP users, admin ≠ admin/administrator | `joafaust42` (admin) + `joafaust` (author) |
| No `latest` tag | `alpine:3.20` everywhere |
| No passwords in Dockerfiles | All passwords read from `/run/secrets/` at runtime |
| `.env` for environment variables | `srcs/.env` + `env_file:` in docker-compose |
| Docker secrets for credentials | `secrets:` block in docker-compose; files in `secrets/` |
| Secrets not in git | `secrets/` and `srcs/.env` in `.gitignore` |
| NGINX only entry point on port 443 | Only port `443:443` published in docker-compose |
| Domain `login.42.fr` | `DOMAIN_NAME=joafaust.42.fr` in `.env`; add to `/etc/hosts` |
