# User documentation

How to run and use the Inception stack. Run all commands from the root of the repository.

## What is provided

| Service | What it does | Reachable from |
|---------|--------------|----------------|
| nginx | HTTPS web server, the only way into the stack | your browser, port 443 |
| wordpress | The website and its admin panel (php-fpm) | nginx only |
| mariadb | The database storing posts, users and comments | wordpress only |

## Start and stop

```sh
make           # build (if needed) and start everything in the background
make ps        # show container status: all three should be "Up"
make stop      # stop the containers, keep them
make down      # stop and remove the containers, keep the data
make logs      # follow the logs (Ctrl+C to quit)
```

The containers restart automatically after a crash or a reboot (`restart: unless-stopped`). After a VM reboot, run `make` again if they aren't up.

**Warning:** `make clean`, `make fclean` and `make re` delete all website and database data in `/home/joafaust/data`.

## Access the website and admin panel

The domain `joafaust.42.fr` must point to the machine. Check with `grep joafaust /etc/hosts`.

| What | URL |
|------|-----|
| Website | https://joafaust.42.fr |
| Admin panel | https://joafaust.42.fr/wp-admin |

The certificate is self-signed, so the browser shows a warning the first time. Choose *Advanced → Accept the risk and continue*. Plain `http://` is intentionally not available.

Accounts:
- **Administrator:** username in `WP_ADMIN_USER` in `srcs/.env`, password on line 1 of `secrets/credentials.txt`
- **Regular user (author):** username in `WP_USER` in `srcs/.env`, password on line 2 of `secrets/credentials.txt`

## Manage credentials

| File | Contains |
|------|----------|
| `secrets/db_password.txt` | Password of the WordPress database user (`MYSQL_USER`) |
| `secrets/db_root_password.txt` | Password of the MariaDB `root` user |
| `secrets/credentials.txt` | Line 1: WordPress admin password. Line 2: WordPress user password |
| `srcs/.env` | Domain, database name, usernames and emails (no passwords) |

These files are git-ignored and must never be committed.

The passwords are only applied on the **first** install. To change them later:
- **WordPress passwords:** use *Users → Profile* in the admin panel, or run `docker exec wordpress wp user update <user> --user_pass=<new> --allow-root --path=/var/www/html`.
- **To start over with new secrets:** run `make fclean` (this deletes all data), edit the files, then run `make`.

## Basic checks

```sh
make ps                                                   # 3 containers "Up"
docker logs wordpress | tail                              # ends with "Success: Created user 2." on first run
openssl s_client -connect joafaust.42.fr:443 -tls1_2 </dev/null 2>/dev/null | grep Protocol   # TLSv1.2
docker exec wordpress wp user list --allow-root --path=/var/www/html                          # 2 users
docker exec -it mariadb mariadb -u wpuser -p wordpress -e 'SHOW TABLES;'                        # password: secrets/db_password.txt
```

If the site doesn't load, check `make ps` and then `make logs` to see which container is failing.
