#!/bin/bash

DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
DB_PASSWORD_B64=$(echo -n "$DB_PASSWORD" | base64)

cat > k8s/db-secret.yml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  labels:
    app: projet-final
    tier: db
type: Opaque
data:
  POSTGRES_PASSWORD: $DB_PASSWORD_B64
EOF

cat > k8s/back-config-secret.yml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: back-config
  labels:
    app: projet-final
    tier: back
data:
  DB_HOST: "postgres-db-service"
  DB_PORT: "5432"
  DB_USER: "user"
  DB_NAME: "mydb"
  BACK_PORT: "8080"

---
apiVersion: v1
kind: Secret
metadata:
  name: back-secret
  labels:
    app: projet-final
    tier: back
type: Opaque
data:
  DB_PASSWORD: $DB_PASSWORD_B64
EOF

echo "Secrets generes"
echo "DB_PASSWORD=$DB_PASSWORD"
