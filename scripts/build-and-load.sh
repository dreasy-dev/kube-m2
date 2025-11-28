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

