#!/bin/sh
set -e

# ── Read secrets ───────────────────────────────────────────────────────────
DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASS=$(head -n 1 /run/secrets/credentials)
WP_USER_PASS=$(tail -n 1 /run/secrets/credentials)

WP_PATH=/var/www/html

mkdir -p "${WP_PATH}"

# ── First-run setup (skipped on container restart because volume persists) ─
if [ ! -f "${WP_PATH}/wp-config.php" ]; then

    # 1. Download WordPress core
    wp core download --path="${WP_PATH}" --allow-root

    # 2. Generate wp-config.php  (no passwords inside the image)
    wp config create \
        --path="${WP_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost=mariadb \
        --allow-root

    # 3. Wait for MariaDB to accept connections
    echo "Waiting for MariaDB to be ready..."
    until wp db check --path="${WP_PATH}" --allow-root 2>/dev/null; do
        sleep 2
    done

    # 4. Install WordPress (creates tables, sets admin account)
    wp core install \
        --path="${WP_PATH}" \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    # 5. Create a second (non-admin) user
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASS}" \
        --path="${WP_PATH}" \
        --allow-root

    # 6. Fix ownership so php-fpm (nobody) can write uploads etc.
    chown -R nobody:nobody "${WP_PATH}"
    find "${WP_PATH}" -type d -exec chmod 755 {} \;
    find "${WP_PATH}" -type f -exec chmod 644 {} \;
fi

# ── Start php-fpm as PID 1 (exec replaces this shell) ─────────────────────
exec php-fpm82 -F
