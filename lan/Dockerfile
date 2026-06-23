FROM caddy:2-alpine

COPY scripts/ /srv/scripts/
COPY lan/ /srv/lan/
COPY lan/Caddyfile /etc/caddy/Caddyfile

RUN caddy fmt --overwrite /etc/caddy/Caddyfile || true

EXPOSE 80

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
