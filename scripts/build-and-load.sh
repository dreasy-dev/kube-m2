#!/bin/bash

set -e

echo "Construction des images Docker..."

cd app/backend
docker build -t projet-final-back:latest .
echo "Image backend construite"

cd ../frontend
docker build -t projet-final-front:latest .
echo "Image frontend construite"

cd ../..

echo "Images construites. Pour un cluster local (minikube/kind), chargez-les manuellement:"
echo "  minikube: minikube image load projet-final-back:latest && minikube image load projet-final-front:latest"
echo "  kind: kind load docker-image projet-final-back:latest && kind load docker-image projet-final-front:latest"
echo "Pour un cluster distant, utilisez un registry Docker."
