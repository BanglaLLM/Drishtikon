#!/bin/bash

set -e

CLUSTER_NAME="drishtikon"
VERSION="v1.0.0"

# Function to install kind
install_kind() {
  echo "Installing kind..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-darwin-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
  elif [[ "$OSTYPE" == "msys" ]]; then
    curl -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/latest/kind-windows-amd64
    chmod +x kind-windows-amd64.exe
    mv kind-windows-amd64.exe /usr/local/bin/kind.exe
  else
    echo "Unsupported OS. Please install kind manually."
    exit 1
  fi
}

# Check if kind is installed
if ! command -v kind &> /dev/null; then
  install_kind
else
  echo "kind is already installed"
fi

# Create the Kind cluster if it does not exist
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Creating Kind cluster: $CLUSTER_NAME"
  kind create cluster --name $CLUSTER_NAME
else
  echo "Kind cluster $CLUSTER_NAME already exists"
fi

# Build Docker images
echo "Building Docker images"
docker build -t data-crawling:$VERSION ./data-crawling
docker build -t data-analytics:$VERSION ./data-analytics

# Load Docker images into kind cluster
echo "Loading Docker images into Kind cluster: $CLUSTER_NAME"
kind load docker-image data-crawling:$VERSION --name $CLUSTER_NAME
kind load docker-image data-analytics:$VERSION --name $CLUSTER_NAME

# Deploy Elasticsearch using Helm
echo "Deploying Elasticsearch using Helm"
helm install data-storage ./data-storage/helm

# Deploy other services using kubectl
echo "Deploying data-crawling service"
kubectl apply -f ./data-crawling/k8s/deployment.yaml
echo "Deploying data-analytics service"
kubectl apply -f ./data-analytics/k8s/deployment.yaml

echo "Deployment completed successfully"
