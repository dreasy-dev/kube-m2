# Architecture du Projet Final

## Vue d'ensemble

Cette application est une architecture 3-tiers déployée sur Kubernetes, composée de :
- **Frontend** : Application SPA (Single Page Application)
- **Backend** : API REST
- **Database** : PostgreSQL

## Diagramme d'architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  NGINX Ingress        │
         │  (port 80/443)        │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│  Front Service   │    │   Back Service   │
│  (ClusterIP)     │    │   (ClusterIP)    │
└────────┬─────────┘    └────────┬─────────┘
         │                       │
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│ Front Deployment │    │ Back Deployment  │
│ (2 replicas)     │    │ (2 replicas)     │
│                  │    │                  │
│ - LivenessProbe  │    │ - LivenessProbe  │
│ - ReadinessProbe │    │ - ReadinessProbe │
│ - Resources      │    │ - Resources      │
│   limits/req     │    │   limits/req     │
└──────────────────┘    └────────┬─────────┘
                                 │
                                 │ HTTP/JSON
                                 ▼
                    ┌──────────────────────────┐
                    │   Postgres DB Service    │
                    │      (ClusterIP)         │
                    └────────────┬─────────────┘
                                 │
                                 ▼
                    ┌──────────────────────────┐
                    │   Postgres Deployment    │
                    │      (1 replica)         │
                    │                          │
                    │ - PVC (5Gi)              │
                    │ - Resources limits/req   │
                    └──────────────────────────┘
```

## Composants Kubernetes

### 1. Frontend

- **Deployment** : `front-deployment`
  - Replicas : 2
  - Image : SPA conteneurisée (nginx + build statique)
  - Port : 80
  - Resources :
    - Requests : 32Mi RAM, 50m CPU
    - Limits : 64Mi RAM, 100m CPU
  - Probes :
    - Liveness : GET / (port 80)
    - Readiness : GET / (port 80)

- **Service** : `front-service`
  - Type : ClusterIP
  - Port : 80 → 80

### 2. Backend

- **Deployment** : `back-deployment`
  - Replicas : 2
  - Image : API REST (Node.js/Python/Java/Go)
  - Port : 8080
  - Resources :
    - Requests : 64Mi RAM, 100m CPU
    - Limits : 128Mi RAM, 250m CPU
  - Probes :
    - Liveness : GET /health (port 8080)
    - Readiness : GET /ready (port 8080)
  - Env : ConfigMap `back-config` + Secret `back-secret`

- **Service** : `back-service`
  - Type : ClusterIP
  - Port : 80 → 8080

- **ConfigMap** : `back-config`
  - DB_HOST: postgres-db-service
  - DB_PORT: 5432
  - DB_USER: user
  - DB_NAME: mydb
  - BACK_PORT: 8080

- **Secret** : `back-secret`
  - DB_PASSWORD: (base64 encoded)

### 3. Database

- **Deployment** : `postgres-db-deployment`
  - Replicas : 1 (pour la cohérence des données)
  - Image : postgres:15
  - Port : 5432
  - Resources :
    - Requests : 128Mi RAM, 250m CPU
    - Limits : 256Mi RAM, 500m CPU
  - Volume : PVC `db-pvc` monté sur `/var/lib/postgresql/data`

- **Service** : `postgres-db-service`
  - Type : ClusterIP
  - Port : 5432 → 5432

- **Secret** : `db-secret`
  - POSTGRES_PASSWORD: (base64 encoded)

- **PVC** : `db-pvc`
  - Storage : 5Gi
  - AccessMode : ReadWriteOnce
  - StorageClass : standard

### 4. Ingress

- **Ingress** : `front-ingress`
  - Controller : NGINX
  - Routes :
    - `/` → front-service (port 80)
    - `/api` → back-service (port 80)

## Flux de données

1. **Requête utilisateur** → Ingress NGINX
2. **Route frontend** (`/`) → Front Service → Front Pod
3. **Route API** (`/api`) → Back Service → Back Pod
4. **Requête DB** → Back Pod → Postgres Service → Postgres Pod

## Stratégies de déploiement

### RollingUpdate
- **maxSurge** : 1 (permet 1 pod supplémentaire pendant le déploiement)
- **maxUnavailable** : 0 (garantit la disponibilité continue)
- **Avantage** : Zéro downtime lors des mises à jour

## Sécurité

1. **Non-root users** : Tous les conteneurs tournent avec un utilisateur non-privilegié
2. **Secrets chiffrés** : Les mots de passe sont stockés dans des Secrets Kubernetes (base64)
3. **Resources limits** : Prévention des attaques DoS par consommation excessive
4. **Network policies** : Services en ClusterIP (pas d'exposition directe)

## Persistance

- **PVC** : 5Gi de stockage persistant pour PostgreSQL
- **StorageClass** : standard (provisionnement dynamique)
- **Backup** : À configurer selon les besoins (snapshots, pg_dump, etc.)

## Scaling

- **Horizontal Pod Autoscaling** : Peut être ajouté avec HPA basé sur CPU/mémoire
- **Réplicas actuels** :
  - Frontend : 2
  - Backend : 2
  - Database : 1 (recommandé pour la cohérence)

## Observabilité

- **Logs** : Accessibles via `kubectl logs`
- **Labels** : Cohérents (app: projet-final, tier: front/back/db, version: v1)
- **Probes** : Monitoring de santé intégré
- **Resources** : Monitoring via métriques Kubernetes

## Choix techniques justifiés

### Kubernetes
- Orchestration moderne et standard de l'industrie
- Gestion automatique du scaling, health checks, rolling updates

### PostgreSQL
- Base de données relationnelle robuste
- Support JSON pour flexibilité
- Image officielle bien maintenue

### ConfigMaps & Secrets
- Séparation configuration/sensibilités
- Gestion centralisée de la configuration
- Pas de secrets en clair dans les images

### PVC
- Persistance garantie des données
- Survit aux redémarrages de pods
- Provisionnement dynamique

### RollingUpdate
- Zéro downtime
- Rollback facile en cas de problème
- Délais configurables pour readiness

### Resources limits
- Prévention de la consommation excessive
- Allocation prévisible des ressources
- Meilleure planification de capacité

