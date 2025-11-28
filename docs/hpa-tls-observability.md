# HPA, TLS et Kustomize

## Table des matières

- [Horizontal Pod Autoscaler (HPA)](#horizontal-pod-autoscaler-hpa)
- [TLS / HTTPS](#tls--https)
- [Kustomize](#kustomize)

## Horizontal Pod Autoscaler (HPA)

### Installation de Metrics Server

Metrics Server est requis pour que HPA fonctionne :

```bash
# Installation officielle (recommandé)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Ou utiliser notre version locale
kubectl apply -f k8s/metrics-server.yml
```

Vérifier l'installation :
```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
kubectl top pods
```

### Déploiement des HPA

```bash
# HPA pour backend (2-10 replicas basés sur CPU/Memory)
kubectl apply -f k8s/hpa-back.yml

# HPA pour frontend (2-8 replicas basés sur CPU/Memory)
kubectl apply -f k8s/hpa-front.yml

# Vérifier les HPA
kubectl get hpa
kubectl describe hpa back-hpa
```

### Configuration HPA

Les HPA sont configurés pour :
- **CPU** : Scaling à 70% d'utilisation
- **Memory** : Scaling à 80% d'utilisation
- **Scale Up** : Agressif (100% ou +2 pods en 30s)
- **Scale Down** : Conservateur (50% ou -1 pod en 60s, avec fenêtre de stabilisation de 5min)

### Surveillance des HPA

```bash
# Voir les événements de scaling
kubectl get hpa -w

# Détails d'un HPA
kubectl describe hpa back-hpa

# Voir les métriques actuelles
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/default/pods
```

## TLS / HTTPS

### Installation de cert-manager

```bash
# Installation de cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Vérifier l'installation
kubectl get pods -n cert-manager
```

### Configuration ClusterIssuer

Éditez `k8s/cert-manager-issuer.yml` et remplacez l'email :

```bash
sed -i 's/votre-email@example.com/votre-vrai-email@domain.com/g' k8s/cert-manager-issuer.yml
kubectl apply -f k8s/cert-manager-issuer.yml
```

### Configuration Ingress avec TLS

1. Remplacez le domaine dans `k8s/front-ingress-tls.yml` :
```bash
sed -i 's/projet-final.example.com/votre-domaine.com/g' k8s/front-ingress-tls.yml
```

2. Appliquez l'ingress TLS :
```bash
kubectl apply -f k8s/front-ingress-tls.yml
```

3. Vérifier le certificat :
```bash
kubectl get certificate
kubectl describe certificate front-tls-secret
```

Le certificat Let's Encrypt sera généré automatiquement (peut prendre quelques minutes).

### Utilisation de l'Ingress TLS

L'ingress TLS inclut :
- ✅ Redirection HTTP → HTTPS automatique
- ✅ Certificat SSL/TLS automatique via Let's Encrypt
- ✅ Renouvellement automatique des certificats
- ✅ Rate limiting (100 req/s, 10 connexions simultanées)

## Kustomize

### Structure

```
kustomize/
├── base/                    # Configuration de base
│   └── kustomization.yml
└── overlays/
    ├── dev/                 # Environnement de développement
    │   ├── kustomization.yml
    │   ├── deployment-patch.yml
    │   └── resources-patch.yml
    └── prod/                # Environnement de production
        ├── kustomization.yml
        ├── deployment-patch.yml
        ├── ingress-tls-patch.yml
        └── hpa-patch.yml
```

### Utilisation

#### Build (prévisualisation)

```bash
# Prévisualiser la configuration dev
kubectl kustomize kustomize/overlays/dev

# Prévisualiser la configuration prod
kubectl kustomize kustomize/overlays/prod
```

#### Déploiement

```bash
# Déployer en dev
kubectl apply -k kustomize/overlays/dev

# Déployer en prod
kubectl apply -k kustomize/overlays/prod
```

#### Différences Dev vs Prod

| Aspect | Dev | Prod |
|--------|-----|------|
| Replicas | 1 | 3 |
| Resources | Réduites | Standards |
| TLS | Non | Oui |
| HPA min | 2 | 3 |
| HPA max | 10/8 | 20/15 |
| Namespace | projet-final-dev | projet-final-prod |

### Personnalisation

Éditez les fichiers dans `kustomize/overlays/<env>/` pour :
- Ajuster les ressources
- Modifier le nombre de replicas
- Ajouter des variables d'environnement
- Configurer des patches spécifiques

## Commandes utiles

### HPA

```bash
# Voir les HPA
kubectl get hpa

# Détails d'un HPA
kubectl describe hpa back-hpa

# Éditer un HPA
kubectl edit hpa back-hpa

# Supprimer un HPA (scaling manuel)
kubectl delete hpa back-hpa
```

### TLS / Certificates

```bash
# Voir les certificats
kubectl get certificate

# Voir les ClusterIssuers
kubectl get clusterissuer

# Voir les événements de certificat
kubectl describe certificate front-tls-secret

# Voir les secrets TLS
kubectl get secret front-tls-secret
```

## Checklist de déploiement

### HPA
- [ ] Metrics Server installé
- [ ] HPA backend déployé
- [ ] HPA frontend déployé
- [ ] Vérifier `kubectl top pods` fonctionne

### TLS
- [ ] cert-manager installé
- [ ] ClusterIssuer configuré avec email
- [ ] Ingress TLS configuré avec domaine
- [ ] Certificat généré et valide
- [ ] Redirection HTTPS active

### Kustomize
- [ ] Base configurée
- [ ] Overlays dev/prod créés
- [ ] Test de build réussi
- [ ] Déploiement testé en dev puis prod

## Troubleshooting

### HPA ne scale pas

```bash
# Vérifier Metrics Server
kubectl get pods -n kube-system | grep metrics-server
kubectl logs -n kube-system deployment/metrics-server

# Vérifier les métriques disponibles
kubectl top pods

# Vérifier les événements HPA
kubectl describe hpa back-hpa | grep Events -A 10
```

### Certificat TLS non généré

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager

# Voir les événements de certificat
kubectl describe certificate front-tls-secret

# Vérifier les challenges ACME
kubectl get challenges
```

