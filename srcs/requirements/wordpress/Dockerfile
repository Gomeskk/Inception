# Penultimate stable Alpine
FROM alpine:3.20

# PHP 8.2 + php-fpm + extensions required by WordPress + WP-CLI
# (mariadb-client provides mysqlcheck, used by "wp db check")
RUN apk update && apk add --no-cache \
    php82 \
    php82-fpm \
    php82-mysqli \
    php82-curl \
    php82-dom \
    php82-fileinfo \
    php82-mbstring \
    php82-openssl \
    php82-phar \
    php82-session \
    php82-tokenizer \
    php82-xml \
    php82-zip \
    mariadb-client \
    wget \
    curl

# php82 binary is named php82; WP-CLI needs a 'php' in PATH
RUN ln -sf /usr/bin/php82 /usr/bin/php

# php-fpm must listen on all interfaces (not just loopback) so NGINX can reach it
# also expose env vars passed by docker-compose to php-fpm workers
RUN sed -i 's/^listen = .*/listen = 9000/'           /etc/php82/php-fpm.d/www.conf && \
    sed -i 's/^;clear_env = no/clear_env = no/'       /etc/php82/php-fpm.d/www.conf || \
    echo "clear_env = no" >> /etc/php82/php-fpm.d/www.conf

# Default 128M is too small for WP-CLI to extract the WordPress archive
RUN sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php82/php.ini

# Download WP-CLI (stable phar, not a Docker image)
RUN wget -O /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

COPY tools/wp-setup.sh /usr/local/bin/wp-setup.sh
RUN chmod +x /usr/local/bin/wp-setup.sh

EXPOSE 9000

# wp-setup.sh ends with exec php-fpm82, which becomes PID 1
ENTRYPOINT ["/usr/local/bin/wp-setup.sh"]
