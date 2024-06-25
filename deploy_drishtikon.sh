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

# Function to build Docker images and get their hashes
build_images() {
  echo "Building Docker images"
  DATA_CRAWLING_IMAGE_HASH=$(docker build -q -t data-crawling:$VERSION ./data-crawling)
  DATA_ANALYTICS_IMAGE_HASH=$(docker build -q -t data-analytics:$VERSION ./data-analytics)
  echo "Data Crawling image hash: $DATA_CRAWLING_IMAGE_HASH"
  echo "Data Analytics image hash: $DATA_ANALYTICS_IMAGE_HASH"
}

# Function to load Docker images into Kind cluster
load_images() {
  echo "Loading Docker images into Kind cluster: $CLUSTER_NAME"
  kind load docker-image data-crawling:$VERSION --name $CLUSTER_NAME
  kind load docker-image data-analytics:$VERSION --name $CLUSTER_NAME
}

# Function to delete old Docker images from Kind nodes
delete_old_images_from_kind() {
  echo "Checking and deleting old Docker images from Kind nodes"
  for node in $(kind get nodes --name $CLUSTER_NAME); do
    # Data Crawling images
    DATA_CRAWLING_IMAGES=$(docker exec $node crictl images | grep data-crawling)
    DATA_CRAWLING_IMAGE_COUNT=$(echo "$DATA_CRAWLING_IMAGES" | wc -l)
    if [[ $DATA_CRAWLING_IMAGE_COUNT -gt 1 ]]; then
      CURRENT_DATA_CRAWLING_HASH=$(echo "$DATA_CRAWLING_IMAGES" | awk '{print $3}' | grep -v "$DATA_CRAWLING_IMAGE_HASH")
      for HASH in $CURRENT_DATA_CRAWLING_HASH; do
        echo "Deleting old data-crawling image with hash $HASH from node $node"
        docker exec $node crictl rmi $HASH || true
      done
    fi

    # Data Analytics images
    DATA_ANALYTICS_IMAGES=$(docker exec $node crictl images | grep data-analytics)
    DATA_ANALYTICS_IMAGE_COUNT=$(echo "$DATA_ANALYTICS_IMAGES" | wc -l)
    if [[ $DATA_ANALYTICS_IMAGE_COUNT -gt 1 ]]; then
      CURRENT_DATA_ANALYTICS_HASH=$(echo "$DATA_ANALYTICS_IMAGES" | awk '{print $3}' | grep -v "$DATA_ANALYTICS_IMAGE_HASH")
      for HASH in $CURRENT_DATA_ANALYTICS_HASH; do
        echo "Deleting old data-analytics image with hash $HASH from node $node"
        docker exec $node crictl rmi $HASH || true
      done
    fi
  done
}

# Function to deploy services
deploy_services() {
  echo "Deploying Elasticsearch using Helm"
  helm install data-storage ./data-storage/helm --wait

  echo "Deploying data-crawling service"
  kubectl apply -f ./data-crawling/k8s/deployment.yaml

  echo "Deploying data-analytics service"
  kubectl apply -f ./data-analytics/k8s/deployment.yaml

}

# Main function to build, load, and redeploy
main() {
  build_images
  PREV_DATA_CRAWLING_HASH=$(docker images -q data-crawling:$VERSION)
  PREV_DATA_ANALYTICS_HASH=$(docker images -q data-analytics:$VERSION)

  if [[ "$DATA_CRAWLING_IMAGE_HASH" != "$PREV_DATA_CRAWLING_HASH" || "$DATA_ANALYTICS_IMAGE_HASH" != "$PREV_DATA_ANALYTICS_HASH" ]]; then
    load_images
    delete_old_images_from_kind
    deploy_services
  else
    echo "No changes in images, skipping load and deploy"
  fi

  echo "Deployment completed successfully"
  echo "Access data-crawling at http://localhost:8080"
  echo "Access data-analytics at http://localhost:9090"
}

# Run the main function
main

