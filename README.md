# Inception — 42 School Project

Small Docker infrastructure: NGINX (TLS only) → WordPress+php-fpm → MariaDB.

## Quick start (inside your VM)

```sh
# 1. Edit secrets before the first run
nano secrets/credentials.txt        # line 1 = WP admin pass, line 2 = WP user pass
nano secrets/db_password.txt
nano secrets/db_root_password.txt

# 2. Add your domain to /etc/hosts
echo "127.0.0.1  joafaust.42.fr" | sudo tee -a /etc/hosts

# 3. Build and start
make
```

Open **https://joafaust.42.fr** in a browser (accept the self-signed cert).

## Makefile targets

| Target    | Description                                      |
|-----------|--------------------------------------------------|
| `make`    | Create data dirs + build images + start in bg   |
| `make down`   | Stop and remove containers                   |
| `make clean`  | Down + remove volumes, images, host data     |
| `make re`     | Full rebuild from scratch                    |
| `make logs`   | Follow live logs from all containers         |
| `make ps`     | Show container status                        |

## Directory structure

```
Inception/
├── Makefile
├── .gitignore          ← secrets/ and srcs/.env are git-ignored
├── secrets/            ← git-ignored; plain-text secret files
│   ├── credentials.txt         (WP admin pass + WP user pass)
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                    ← git-ignored; non-secret env vars
    ├── docker-compose.yml
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

## Security notes

- Passwords are **never** stored in Dockerfiles or the image layers.  
  They are passed at runtime via Docker secrets (mounted at `/run/secrets/`).
- `secrets/` and `srcs/.env` are in `.gitignore` — **never commit them**.
- NGINX accepts **TLSv1.2 and TLSv1.3 only** on port 443; port 80 is not exposed.
- The `latest` Docker tag is not used anywhere.
