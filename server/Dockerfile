# --- Stage 1: Install production dependencies ---
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# --- Stage 2: Production image ---
FROM node:20-alpine
WORKDIR /app

# Non-root user
RUN addgroup -S p2ptalk && adduser -S p2ptalk -G p2ptalk

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY server.js ./
COPY db.js ./
COPY lib ./lib

# SQLite DB directory (mounted as a volume; DB_PATH should point here in prod).
RUN mkdir -p /app/data && chown -R p2ptalk:p2ptalk /app

USER p2ptalk
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
