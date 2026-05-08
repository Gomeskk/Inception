#!/bin/sh
set -e

# ── Read secrets (mounted by Docker at /run/secrets/) ─────────────────────
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

# ── Runtime socket directory ───────────────────────────────────────────────
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# ── First-run initialisation (skipped on container restart) ───────────────
if [ ! -d "/var/lib/mysql/mysql" ]; then
    chown -R mysql:mysql /var/lib/mysql

    # Create system tables
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    # Bootstrap: create root password, app database, and app user
    mysqld --user=mysql --bootstrap --verbose=0 --skip-networking <<EOF
USE mysql;
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
fi

# ── Start MariaDB as PID 1 (exec replaces this shell) ─────────────────────
exec mysqld --user=mysql
