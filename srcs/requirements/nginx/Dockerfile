# Penultimate stable Alpine
FROM alpine:3.20

RUN apk update && apk add --no-cache nginx openssl

# Self-signed TLS certificate (replace with a real cert in production)
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/server.key \
        -out    /etc/nginx/ssl/server.crt \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=joafaust.42.fr"

# Replace default server block with our config
COPY conf/nginx.conf /etc/nginx/http.d/default.conf

EXPOSE 443

# Run nginx in foreground as PID 1 (no daemon, no tail -f)
CMD ["nginx", "-g", "daemon off;"]
