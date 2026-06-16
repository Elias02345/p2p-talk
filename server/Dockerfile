# --- Stage 1: Install production dependencies ---
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# --- Stage 2: Production image ---
FROM node:20-alpine
WORKDIR /app

# su-exec lets the entrypoint fix volume perms as root, then drop privileges.
RUN apk add --no-cache su-exec && addgroup -S p2ptalk && adduser -S p2ptalk -G p2ptalk

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY server.js ./
COPY db.js ./
COPY lib ./lib
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p /app/data && chown -R p2ptalk:p2ptalk /app && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Entrypoint runs as root only to chown the mounted volume, then execs node as p2ptalk.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "server.js"]
