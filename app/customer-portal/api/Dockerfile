# syntax=docker/dockerfile:1
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:24-alpine
ENV NODE_ENV=production PORT=8080 PGSSLROOTCERT=/app/certs/rds-ca.pem
WORKDIR /app
# Amazon RDS CA bundle: the API verifies the database certificate (required for IAM auth over TLS).
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/rds-ca.pem
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
# Numeric UID so Kubernetes 'runAsNonRoot' can verify it.
USER 1000
EXPOSE 8080
CMD ["node", "src/index.js"]
