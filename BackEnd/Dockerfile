FROM node:20-bookworm-slim

WORKDIR /app/server

ENV NODE_ENV=production

COPY server/package*.json ./
RUN npm ci --omit=dev

COPY server/ ./
COPY dist/ /app/dist/

EXPOSE 3000

CMD ["node", "app.js"]
