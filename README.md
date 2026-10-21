*This project has been created as part of the 42 curriculum by joafaust.*

# Inception

## Description

Inception is a small infrastructure built with Docker Compose inside a virtual machine. It runs three services, each in its own container built from `alpine:3.20` with a hand-written Dockerfile:

| Service | Role |
|---------|------|
| **nginx** | The only entry point. Serves HTTPS on port 443 with TLSv1.2/TLSv1.3 and a self-signed certificate, and forwards PHP requests to WordPress. |
| **wordpress** | WordPress with php-fpm (port 9000, internal only). Installed and configured automatically with WP-CLI on first start. |
| **mariadb** | The WordPress database (port 3306, internal only). |

```
Browser ──HTTPS:443──▶ nginx ──FastCGI:9000──▶ wordpress ──MySQL:3306──▶ mariadb
                       └──────────── Docker bridge network "inception" ───────────┘
```

The website and database data are stored in two named volumes, which keep their data in `/home/joafaust/data/` on the host, so the data survives restarts and reboots. Passwords are passed as Docker secrets and never stored in an image or in git.

### Design choices

**Virtual Machines vs Docker**
A VM emulates a whole computer with its own kernel, so it is heavy (GBs, slow to boot) but fully isolated. A Docker container shares the host kernel and only isolates processes, filesystem and network with namespaces and cgroups. It starts in seconds, uses few resources, and is described by a Dockerfile that can be rebuilt the same way anywhere. This project uses both: a VM as the host, with Docker containers for each service inside it.

**Secrets vs Environment Variables**
Environment variables (`srcs/.env`) hold non-sensitive settings such as the domain name and usernames. They are visible with `docker inspect` and to every process in the container. Passwords go in Docker secrets (`secrets/*.txt`), which are mounted as read-only files under `/run/secrets/` only in the containers that need them, and never appear in the image or in `docker inspect`. Both `secrets/` and `srcs/.env` are git-ignored.

**Docker Network vs Host Network**
With `network: host` a container uses the host's network directly, with no isolation, and every port it opens is exposed. This project uses a user-defined bridge network (`inception`). The containers reach each other by service name (`mariadb`, `wordpress`) through Docker's built-in DNS, and only nginx's port 443 is published to the host. MariaDB and php-fpm can't be reached from outside.

**Docker Volumes vs Bind Mounts**
A bind mount maps a host path straight into a container, and the host's file layout and permissions leak into the container. A named volume is managed by Docker (`docker volume ls/inspect`) and can be shared between containers by name. The subject requires named volumes stored under `/home/joafaust/data`, so the two volumes use the `local` driver with `driver_opts` (`type: none`, `o: bind`). They remain named volumes that Docker manages, while their data lives at the required host path.

## Instructions

Prerequisites: a Linux VM with Docker Engine, the Docker Compose v2 plugin, `make`, and `sudo`.

```sh
# 1. Point the domain at this machine
echo "127.0.0.1  joafaust.42.fr" | sudo tee -a /etc/hosts

# 2. Create the secrets (one password per file; credentials.txt has two lines)
mkdir -p secrets
echo "<db user password>"  > secrets/db_password.txt
echo "<db root password>"  > secrets/db_root_password.txt
printf '%s\n%s\n' "<wp admin password>" "<wp user password>" > secrets/credentials.txt

# 3. Create srcs/.env (see DEV_DOC.md for the full list of variables)

# 4. Build and start
make
```

Open **https://joafaust.42.fr** and accept the self-signed certificate warning. The admin panel is at **https://joafaust.42.fr/wp-admin**.

| Target | Description |
|--------|-------------|
| `make` | Create the data folders, build the images, start everything in the background |
| `make down` | Stop and remove the containers (data is kept) |
| `make stop` | Stop the containers without removing them |
| `make clean` / `make fclean` | Remove containers, volumes, images **and the data in `/home/joafaust/data`** |
| `make re` | `fclean` followed by `all` (full reinstall) |
| `make logs` | Follow the logs of all containers |
| `make ps` | Show container status |

See [USER_DOC.md](USER_DOC.md) for day-to-day usage and [DEV_DOC.md](DEV_DOC.md) for developer details.

## Resources

- [Docker documentation](https://docs.docker.com/): Dockerfile reference, Compose file reference, secrets, volumes, networking
- [Alpine Linux packages](https://pkgs.alpinelinux.org/packages)
- [NGINX documentation](https://nginx.org/en/docs/): `ngx_http_ssl_module`, FastCGI
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/): server configuration, `mysql_install_db`
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/): `core download`, `config create`, `core install`, `user create`
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### How AI was used

AI (Claude) was used as an assistant for:
- **Debugging the first run.** It found three bugs from the container logs: PHP's 128M memory limit was too small for `wp core download`; Alpine's `mariadb-server.cnf` set `skip-networking` and overrode our config; and `mariadb-client` was missing, so `wp db check` could never succeed.
- **Setting up the VM.** It wrote the commands for installing Docker, the hosts entry and the data folders.
- **Documentation.** It drafted this README, USER_DOC.md and DEV_DOC.md.

Every change was reviewed, tested on the VM and understood before being kept.
