# Penultimate stable Alpine
FROM alpine:3.23

# PHP 8.3 + php-fpm + extensions required by WordPress + WP-CLI
# (mariadb-client provides mysqlcheck, used by "wp db check")
RUN apk update && apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-curl \
    php83-dom \
    php83-fileinfo \
    php83-mbstring \
    php83-openssl \
    php83-phar \
    php83-session \
    php83-tokenizer \
    php83-xml \
    php83-zip \
    mariadb-client \
    wget \
    curl

# php83 binary is named php83; WP-CLI needs a 'php' in PATH
RUN ln -sf /usr/bin/php83 /usr/bin/php

# php-fpm must listen on all interfaces (not just loopback) so NGINX can reach it
# also expose env vars passed by docker-compose to php-fpm workers
RUN sed -i 's/^listen = .*/listen = 9000/'           /etc/php83/php-fpm.d/www.conf && \
    sed -i 's/^;clear_env = no/clear_env = no/'       /etc/php83/php-fpm.d/www.conf || \
    echo "clear_env = no" >> /etc/php83/php-fpm.d/www.conf

# Default 128M is too small for WP-CLI to extract the WordPress archive
RUN sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php83/php.ini

# Download WP-CLI (stable phar, not a Docker image)
RUN wget -O /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

COPY tools/wp-setup.sh /usr/local/bin/wp-setup.sh
RUN chmod +x /usr/local/bin/wp-setup.sh

EXPOSE 9000

# wp-setup.sh ends with exec php-fpm82, which becomes PID 1
ENTRYPOINT ["/usr/local/bin/wp-setup.sh"]
