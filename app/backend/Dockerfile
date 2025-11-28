FROM node:18-alpine
WORKDIR /app
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
COPY package*.json ./
RUN npm install --omit=dev && chown -R nodejs:nodejs /app
COPY --chown=nodejs:nodejs . .
USER nodejs
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1
CMD ["node", "server.js"]
