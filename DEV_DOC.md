# Developer documentation

How to set up, build and work on the Inception stack. For a detailed walkthrough of every file, see [GUIDE.md](GUIDE.md).

## Prerequisites

- A Linux VM (tested on Ubuntu) with `sudo`
- Docker Engine and the Docker Compose v2 plugin (`docker compose`), plus `make` and `git`

On Ubuntu:

```sh
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2 make git
sudo usermod -aG docker $USER      # then log out and back in
```

## Setup from scratch

```sh
git clone <repo-url> Inception && cd Inception

# Domain
echo "127.0.0.1  joafaust.42.fr" | sudo tee -a /etc/hosts

# Host folders for the volumes (make also creates them; the parent must be writable)
sudo mkdir -p /home/joafaust/data && sudo chown -R $USER:$USER /home/joafaust

# Secrets (random passwords)
mkdir -p secrets
gen() { openssl rand -base64 18 | tr -d '/+='; }
gen > secrets/db_password.txt
gen > secrets/db_root_password.txt
{ gen; gen; } > secrets/credentials.txt     # line 1 admin, line 2 user
```

Create `srcs/.env`:

```ini
DOMAIN_NAME=joafaust.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_ADMIN_USER=joafaust42          # must not contain "admin"
WP_ADMIN_EMAIL=joafaust42@joafaust.42.fr

WP_USER=joafaust
WP_USER_EMAIL=user@joafaust.42.fr
```

Then run `make`.

## Project layout

```
Makefile                  entry point
secrets/                  git-ignored Docker secrets
srcs/.env                 git-ignored environment variables
srcs/docker-compose.yml   services, volumes, network, secrets
srcs/requirements/
  nginx/      Dockerfile, conf/nginx.conf             (TLS, FastCGI to wordpress:9000)
  mariadb/    Dockerfile, conf/50-server.cnf, tools/db-setup.sh
  wordpress/  Dockerfile, tools/wp-setup.sh
```

Each entrypoint script does its first-run setup and then `exec`s the service (`nginx`, `mysqld`, `php-fpm82`) so it runs as PID 1 in the foreground.

## Makefile

| Target | Runs |
|--------|------|
| `all` (default) | `setup`, then `docker compose -f srcs/docker-compose.yml up -d --build` |
| `setup` | `mkdir -p /home/joafaust/data/{wordpress,mariadb}` |
| `down` / `stop` | `docker compose down` / `docker compose stop` |
| `clean`, `fclean` | `down --volumes --rmi all`, then `sudo rm -rf /home/joafaust/data` |
| `re` | `fclean all` |
| `logs` / `ps` | `docker compose logs -f` / `docker compose ps` |

## Useful docker compose commands

```sh
C="docker compose -f srcs/docker-compose.yml"
$C up -d --build wordpress         # rebuild and restart one service
$C ps
$C logs -f mariadb
$C exec wordpress sh               # shell inside a container
$C exec mariadb mysql -u root -p   # root password: secrets/db_root_password.txt
docker network ls                  # srcs_inception
docker volume inspect srcs_wordpress srcs_mariadb
```

After changing a Dockerfile or config file, run `$C up -d --build` (keeps the data) or `make re` (wipes the data).

## Data persistence

| Volume | Container path | Host path |
|--------|----------------|-----------|
| `srcs_wordpress` | `/var/www/html` (in nginx and wordpress) | `/home/joafaust/data/wordpress` |
| `srcs_mariadb` | `/var/lib/mysql` | `/home/joafaust/data/mariadb` |

The setup scripts only initialise on the first run:
- **mariadb** skips setup if `/var/lib/mysql/mysql` exists.
- **wordpress** skips setup if `wp-config.php` exists.

So data survives `make down`, container restarts and VM reboots. Only `make clean`/`fclean`/`re` delete it. The MariaDB files belong to the container's `mysql` user, so deleting them from the host needs `sudo`.

## Changing a port (example: nginx 443 → 8443)

1. In `srcs/requirements/nginx/conf/nginx.conf`, set `listen 8443 ssl;`.
2. In `srcs/docker-compose.yml`, set `ports: - "8443:8443"`.
3. Run `make down && make`.
4. WordPress stores its URL in the database, so update it too:
   ```sh
   docker exec wordpress wp option update home    'https://joafaust.42.fr:8443' --allow-root --path=/var/www/html
   docker exec wordpress wp option update siteurl 'https://joafaust.42.fr:8443' --allow-root --path=/var/www/html
   ```
5. Open https://joafaust.42.fr:8443.
