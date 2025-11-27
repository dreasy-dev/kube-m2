#!/bin/bash

set -e

if ! command -v kubectl &> /dev/null; then
    echo "kubectl non installe"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "Impossible de se connecter au cluster"
    exit 1
fi

if [ ! -f "k8s/db-secret.yml" ] || grep -q "mdp_base64" k8s/db-secret.yml 2>/dev/null; then
    ./scripts/generate-secrets.sh
fi


kubectl apply -f k8s/db-secret.yml
kubectl apply -f k8s/back-config-secret.yml
kubectl apply -f k8s/db-pvc.yml
kubectl apply -f k8s/db-deployment.yml

kubectl wait --for=condition=ready pod -l tier=db --timeout=120s || true

kubectl apply -f k8s/back-deployment.yml
kubectl apply -f k8s/front-deployment.yml
kubectl apply -f k8s/front-ingress.yml

if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    kubectl apply -f k8s/hpa-back.yml 2>/dev/null || true
    kubectl apply -f k8s/hpa-front.yml 2>/dev/null || true
fi

sleep 10

kubectl get pods -l app=projet-final
kubectl get services -l app=projet-final
kubectl get ingress

INGRESS_IP=$(kubectl get ingress front-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "$INGRESS_IP" ]; then
    echo "Frontend: http://$INGRESS_IP/"
    echo "API: http://$INGRESS_IP/api"
fi
