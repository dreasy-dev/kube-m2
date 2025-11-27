# Guide de sécurité

## Gestion des secrets

### État actuel

Les secrets sont stockés dans des objets Kubernetes `Secret`, qui sont encodés en base64 (pas chiffrés par défaut).

### Secrets actuels

1. **db-secret** : Mot de passe PostgreSQL
2. **back-secret** : Mot de passe de connexion DB pour le backend

### Génération sécurisée des secrets

Le script `scripts/generate-secrets.sh` génère automatiquement un mot de passe aléatoire et le code en base64.

```bash
./scripts/generate-secrets.sh
```

### Améliorations recommandées

#### 1. Sealed Secrets (recommandé)

Installer Sealed Secrets Controller :
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

Créer un secret scellé :
```bash
# Créer un secret local
echo -n "mon_mot_de_passe" | kubectl create secret generic db-secret \
  --dry-run=client --from-file=POSTGRES_PASSWORD=/dev/stdin -o yaml > secret.yaml

# Sceller le secret
kubectl seal < secret.yaml > sealed-secret.yaml

# Le sealed-secret.yaml peut être commité dans Git
```

#### 2. SOPS (Secrets Operations)

Installation :
```bash
# macOS
brew install sops

# Linux
wget https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux
```

Chiffrer avec SOPS :
```bash
# Chiffrer un fichier secret
sops --encrypt k8s/db-secret.yml > k8s/db-secret.encrypted.yml

# Décrypter pour déploiement
sops --decrypt k8s/db-secret.encrypted.yml | kubectl apply -f -
```

#### 3. External Secrets Operator

Alternative pour intégrer avec des gestionnaires de secrets externes (AWS Secrets Manager, HashiCorp Vault, etc.).

#### 4. Secrets dans CI/CD

**GitHub Actions** : Utiliser GitHub Secrets
```yaml
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

**GitLab CI** : Utiliser GitLab CI/CD Variables (masquées)

### Bonnes pratiques

1. ✅ **Ne jamais commit de secrets en clair dans Git**
2. ✅ **Utiliser des secrets Kubernetes (même si base64)**
3. ✅ **Limiter l'accès RBAC aux secrets**
4. ✅ **Rotation régulière des mots de passe**
5. ✅ **Chiffrer les secrets au repos (Sealed Secrets, SOPS, etc.)**

## Configuration RBAC (Role-Based Access Control)

### Service Account pour les applications

Créer des ServiceAccounts dédiés :

```yaml
# k8s/serviceaccounts.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: back-serviceaccount
  labels:
    app: projet-final
    tier: back
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: front-serviceaccount
  labels:
    app: projet-final
    tier: front
```

Mettre à jour les deployments pour utiliser les ServiceAccounts :

```yaml
spec:
  template:
    spec:
      serviceAccountName: back-serviceaccount
```

### Limiter l'accès aux secrets

Créer un Role pour accéder uniquement aux secrets nécessaires :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: back-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["back-secret"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: back-secret-binding
subjects:
- kind: ServiceAccount
  name: back-serviceaccount
roleRef:
  kind: Role
  name: back-secret-reader
  apiGroup: rbac.authorization.k8s.io
```

## Sécurité des images

### Non-root users

Tous les Dockerfiles sont configurés pour exécuter avec des utilisateurs non-privilegiés :

- **Backend** : `appuser` (UID 1000)
- **Frontend** : `nginx` (UID 1001)

### Scan de vulnérabilités

Le pipeline CI/CD inclut Trivy pour scanner les images Docker :

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
```

Scanner manuellement :
```bash
trivy image votre_username/projet-final-back:latest
trivy image votre_username/projet-final-front:latest
```

### Images distroless (recommandé)

Pour améliorer la sécurité, utiliser des images distroless :
- `gcr.io/distroless/nodejs18-debian11` pour Node.js
- `gcr.io/distroless/python3-debian11` pour Python
- `distroless/static` pour Go

## Network Policies

Restreindre le trafic réseau entre pods :

```yaml
# k8s/network-policies.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: back-network-policy
  labels:
    app: projet-final
    tier: back
spec:
  podSelector:
    matchLabels:
      tier: back
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: front
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: db
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

Appliquer :
```bash
kubectl apply -f k8s/network-policies.yml
```

**Note** : Requiert un CNI supportant Network Policies (Calico, Cilium, etc.)

## Pod Security Standards

Configurer les Pod Security Standards au niveau du namespace :

```yaml
# k8s/namespace-psa.yml
apiVersion: v1
kind: Namespace
metadata:
  name: projet-final
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Security Context

Les Security Context sont déjà configurés dans les Dockerfiles (non-root users). Pour renforcer :

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: backend-api
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

## Ressources et limites

Les limites de ressources sont configurées pour prévenir :
- **DoS par consommation excessive** : Limites CPU/mémoire
- **Attaques par épuisement** : Requests garantis

## Ingress et TLS

### Configuration TLS (recommandé)

Utiliser cert-manager pour générer des certificats Let's Encrypt :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: front-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - votre-domaine.com
    secretName: tls-secret
  rules:
  - host: votre-domaine.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: front-service
            port:
              number: 80
```

### Rate limiting

Ajouter des annotations NGINX pour limiter le débit :

```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "100"
  nginx.ingress.kubernetes.io/limit-connections: "10"
```

## Audit et monitoring

### Événements Kubernetes

Surveiller les événements de sécurité :
```bash
kubectl get events --sort-by='.lastTimestamp' | grep -i "security\|fail\|error"
```

### Logs de sécurité

Centraliser les logs pour détecter les anomalies :
- Falco pour la détection d'intrusion
- Prometheus + Grafana pour le monitoring
- ELK Stack pour l'analyse de logs

## Checklist de sécurité

- [x] Secrets dans des objets Kubernetes Secret
- [x] Images non-root
- [x] Resources limits configurées
- [x] Probes de santé configurées
- [ ] Secrets chiffrés (Sealed Secrets ou SOPS) - À implémenter
- [ ] RBAC configuré - Recommandé
- [ ] Network Policies - Recommandé
- [ ] TLS sur l'Ingress - Recommandé
- [ ] Scan de vulnérabilités dans CI/CD - Configuré
- [ ] Rotation des secrets - À planifier

## Références

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [OWASP Kubernetes Security](https://owasp.org/www-project-kubernetes-top-ten/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)

