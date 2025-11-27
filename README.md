# Projet Final - Déploiement 3-tiers sur Kubernetes

Application 3-tiers (Frontend + Backend + Database) déployée sur Kubernetes.

## Architecture

Internet → Ingress → Front Service → Front Pods (2 replicas)
                  → Back Service  → Back Pods (2 replicas) → DB Service → DB Pod

Composants:
- Frontend: Vue.js SPA avec nginx
- Backend: Node.js API REST
- Database: PostgreSQL 15 avec PVC persistant
- Ingress: NGINX Ingress Controller

## Prérequis

- Kubernetes cluster
- kubectl version 1.24+
- Docker
- NGINX Ingress Controller installé

## Installation

### 1. Générer les secrets

```bash
./scripts/generate-secrets.sh
```

Sauvegardez le mot de passe DB affiché.

### 2. Construire et charger les images Docker

```bash
./scripts/build-and-load.sh
```

Ce script construit les images et les charge dans le cluster si nécessaire.

Pour utiliser un registry Docker, modifiez les images dans les deployments:
```bash
sed -i 's|projet-final-back:latest|votre_username/projet-final-back:latest|g' k8s/back-deployment.yml
sed -i 's|projet-final-front:latest|votre_username/projet-final-front:latest|g' k8s/front-deployment.yml
```

### 3. Déployer

```bash
./scripts/deploy.sh
```

Ou manuellement:
```bash
kubectl apply -f k8s/
```

### 4. Vérifier

```bash
kubectl get pods -l app=projet-final
kubectl get services -l app=projet-final
kubectl get ingress
```

## Structure du projet

```
kube-m2/
├── app/
│   ├── backend/
│   │   └── Dockerfile
│   └── frontend/
│       ├── Dockerfile
│       └── nginx.conf
├── k8s/
│   ├── back-config-secret.yml
│   ├── back-deployment.yml
│   ├── db-deployment.yml
│   ├── db-pvc.yml
│   ├── db-secret.yml
│   ├── front-deployment.yml
│   ├── front-ingress.yml
│   ├── hpa-back.yml
│   ├── hpa-front.yml
│   ├── cert-manager-issuer.yml
│   ├── front-ingress-tls.yml
│   └── metrics-server.yml
├── kustomize/
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
├── monitoring/
│   ├── prometheus-deployment.yml
│   ├── grafana-deployment.yml
│   └── service-monitor.yml
├── scripts/
│   ├── generate-secrets.sh
│   └── deploy.sh
├── .github/workflows/
│   └── ci-cd.yml
└── docs/
    ├── architecture.md
    ├── runbook.md
    ├── security.md
    └── hpa-tls-observability.md
```

## Commandes utiles

```bash
kubectl get pods -l app=projet-final
kubectl logs -l tier=back --tail=50 -f
kubectl logs -l tier=front --tail=50 -f
kubectl scale deployment/back-deployment --replicas=3
kubectl rollout undo deployment/back-deployment
kubectl port-forward svc/front-service 8080:80
```

## Documentation

- architecture.md: Diagrammes et architecture détaillée
- runbook.md: Déploiement, rollback, troubleshooting
- security.md: Gestion secrets, RBAC, bonnes pratiques
- hpa-tls-observability.md: HPA, TLS, Observabilité, Kustomize

## CI/CD

Pipeline GitHub Actions dans `.github/workflows/ci-cd.yml`.

Secrets GitHub requis:
- DOCKER_USERNAME
- DOCKER_PASSWORD
- KUBECONFIG (optionnel)

## Fonctionnalités avancées

HPA: Scaling automatique (hpa-back.yml, hpa-front.yml)
TLS: Certificats SSL automatiques (cert-manager, front-ingress-tls.yml)
Observabilité: Prometheus + Grafana (monitoring/)
Kustomize: Multi-environnements (kustomize/overlays/)

Voir docs/hpa-tls-observability.md pour détails.
