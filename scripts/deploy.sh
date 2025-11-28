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
kubectl apply -f k8s/front-service-nodeport.yml
kubectl apply -f k8s/front-ingress.yml 2>/dev/null || true

if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    kubectl apply -f k8s/hpa-back.yml 2>/dev/null || true
    kubectl apply -f k8s/hpa-front.yml 2>/dev/null || true
fi

sleep 10

kubectl get pods -l app=projet-final
kubectl get services -l app=projet-final

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | head -1)
if [ -n "$NODE_IP" ]; then
    echo ""
    echo "Acces a l'application:"
    echo "  Frontend: http://$NODE_IP:30080/"
    echo "  API: http://$NODE_IP:30080/api"
fi
