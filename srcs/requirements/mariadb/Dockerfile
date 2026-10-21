# Penultimate stable Alpine
FROM alpine:3.20

RUN apk update && apk add --no-cache mariadb mariadb-client

# Custom MariaDB server config
COPY conf/50-server.cnf /etc/my.cnf.d/50-server.cnf

# Alpine's mariadb-server.cnf loads after ours and sets skip-networking
RUN sed -i 's/^skip-networking/#skip-networking/' /etc/my.cnf.d/mariadb-server.cnf

# Database initialisation + startup script
COPY tools/db-setup.sh /usr/local/bin/db-setup.sh
RUN chmod +x /usr/local/bin/db-setup.sh

EXPOSE 3306

# db-setup.sh ends with exec mysqld, so mysqld becomes PID 1
ENTRYPOINT ["/usr/local/bin/db-setup.sh"]
