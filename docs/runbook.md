# Runbook - Guide de déploiement et opérations

## Déploiement initial

### 1. Génération des secrets

```bash
# Générer les secrets avec mot de passe aléatoire
./scripts/generate-secrets.sh

# Vérifier les secrets générés
cat k8s/db-secret.yml
cat k8s/back-config-secret.yml
```

### 2. Construire les images Docker

```bash
./scripts/build-and-load.sh
```

### 3. Déploiement par ordre

```bash
# 1. Créer les secrets et ConfigMaps
kubectl apply -f k8s/db-secret.yml
kubectl apply -f k8s/back-config-secret.yml

# 2. Créer le PVC pour la base de données
kubectl apply -f k8s/db-pvc.yml

# 3. Déployer la base de données
kubectl apply -f k8s/db-deployment.yml

# 4. Vérifier que la DB est prête
kubectl wait --for=condition=ready pod -l tier=db --timeout=120s

# 5. Déployer le backend
kubectl apply -f k8s/back-deployment.yml

# 6. Déployer le frontend
kubectl apply -f k8s/front-deployment.yml

# 7. Déployer l'Ingress
kubectl apply -f k8s/front-ingress.yml
```

### 4. Déploiement en une commande (après configuration)

```bash
kubectl apply -f k8s/
```

### 5. Vérification du déploiement

```bash
# Vérifier les pods
kubectl get pods -l app=projet-final

# Vérifier les services
kubectl get services -l app=projet-final

# Vérifier l'ingress
kubectl get ingress

# Vérifier le PVC
kubectl get pvc

# Voir les logs
kubectl logs -l tier=back --tail=50
kubectl logs -l tier=front --tail=50
kubectl logs -l tier=db --tail=50
```

### 6. Accès à l'application

```bash

# Obtenir l'IP de l'ingress
kubectl get ingress front-ingress
# Accéder à http://<INGRESS_IP>/
```
# 3. Surveiller le déploiement
## Rollback

### Rollback du backend

```bash
# 1. Voir l'historique des déploiements
kubectl rollout history deployment/back-deployment

# 2. Rollback à la version précédente
kubectl rollout undo deployment/back-deployment

# 3. Rollback à une version spécifique
kubectl rollout undo deployment/back-deployment --to-revision=2

# 4. Surveiller le rollback
kubectl rollout status deployment/back-deployment
```

### Rollback du frontend

```bash
kubectl rollout undo deployment/front-deployment
kubectl rollout status deployment/front-deployment
```

## Scaling

### Scale manuel

```bash
# Augmenter le nombre de replicas
kubectl scale deployment/back-deployment --replicas=3
kubectl scale deployment/front-deployment --replicas=3

# Réduire le nombre de replicas
kubectl scale deployment/back-deployment --replicas=2
kubectl scale deployment/front-deployment --replicas=2
```

### Scale automatique (HPA - optionnel)

```bash
# Installer metrics-server (si pas déjà installé)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Créer un HPA pour le backend
kubectl autoscale deployment back-deployment \
  --cpu-percent=70 \
  --min=2 \
  --max=5

# Créer un HPA pour le frontend
kubectl autoscale deployment front-deployment \
  --cpu-percent=70 \
  --min=2 \
  --max=5

# Vérifier le HPA
kubectl get hpa
```

## Troubleshooting

### Pods en erreur

```bash
# Décrire le pod pour voir les événements
kubectl describe pod <pod-name>

# Logs du pod
kubectl logs <pod-name>

# Logs précédents (si le pod a redémarré)
kubectl logs <pod-name> --previous

# Exécuter une commande dans le pod
kubectl exec -it <pod-name> -- /bin/sh
```

### Problèmes de connexion DB

```bash
# Vérifier que le service DB existe
kubectl get svc postgres-db-service

# Tester la connexion depuis un pod backend
kubectl exec -it <back-pod-name> -- sh
# Dans le pod: nc -zv postgres-db-service 5432

# Vérifier les variables d'environnement
kubectl exec <back-pod-name> -- env | grep DB_
```

### Problèmes de probes

```bash
# Tester manuellement les endpoints
kubectl exec -it <back-pod-name> -- wget -qO- http://localhost:8080/health
kubectl exec -it <back-pod-name> -- wget -qO- http://localhost:8080/ready

# Voir les événements du pod
kubectl describe pod <pod-name> | grep -A 10 Events
```

### Problèmes de PVC

```bash
# Vérifier le statut du PVC
kubectl describe pvc db-pvc

# Vérifier les PVs
kubectl get pv

# Voir les événements liés au stockage
kubectl get events --sort-by='.lastTimestamp' | grep pvc
```

### Problèmes d'Ingress

```bash
# Vérifier l'ingress
kubectl describe ingress front-ingress

# Vérifier les pods de l'ingress controller
kubectl get pods -n ingress-nginx

# Logs de l'ingress controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Sauvegarde et restauration

### Sauvegarde de la base de données

```bash
# Créer un job de sauvegarde
kubectl run postgres-backup-$(date +%Y%m%d) \
  --image=postgres:15 \
  --restart=Never \
  --env="PGHOST=postgres-db-service" \
  --env="PGUSER=user" \
  --env="PGPASSWORD=$(kubectl get secret db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)" \
  --env="PGDATABASE=mydb" \
  -- pg_dump mydb > backup-$(date +%Y%m%d).sql

# Copier le backup depuis le pod
kubectl cp postgres-backup-$(date +%Y%m%d):backup.sql ./backup-$(date +%Y%m%d).sql

# Nettoyer
kubectl delete pod postgres-backup-$(date +%Y%m%d)
```

### Restauration

```bash
# Restaurer depuis un backup
kubectl run postgres-restore \
  --image=postgres:15 \
  --restart=Never \
  --env="PGHOST=postgres-db-service" \
  --env="PGUSER=user" \
  --env="PGPASSWORD=$(kubectl get secret db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)" \
  --env="PGDATABASE=mydb" \
  -- psql mydb < backup-YYYYMMDD.sql
```

## Nettoyage

```bash
# Supprimer tous les resources
kubectl delete -f k8s/

# Supprimer spécifiquement
kubectl delete deployment back-deployment front-deployment postgres-db-deployment
kubectl delete service back-service front-service postgres-db-service
kubectl delete ingress front-ingress
kubectl delete pvc db-pvc
kubectl delete secret db-secret back-secret
kubectl delete configmap back-config
```

## Commandes utiles

```bash
# Port-forward pour accès local
kubectl port-forward svc/front-service 8080:80
kubectl port-forward svc/back-service 8081:80
kubectl port-forward svc/postgres-db-service 5432:5432

# Accès à la base de données
kubectl exec -it $(kubectl get pod -l tier=db -o name | head -1) -- psql -U user -d mydb

# Watch des ressources
watch kubectl get pods -l app=projet-final
watch kubectl get all -l app=projet-final

# Top des ressources utilisées
kubectl top pods -l app=projet-final
kubectl top nodes
```

