#!/bin/bash

set -e

CLUSTER_NAME="drishtikon"
VERSION="v1.0.0"

# Ensure submodules are updated
echo "Updating git submodules"
git submodule update --init --recursive

# Function to build Docker images and get their hashes
build_images() {
  echo "Building Docker images"
  BACKEND_IMAGE_HASH=$(docker build -q -t perplexica-backend:$VERSION ./perplexica -f perplexica/backend.dockerfile)
  FRONTEND_IMAGE_HASH=$(docker build -q -t perplexica-frontend:$VERSION ./perplexica -f perplexica/app.dockerfile)
  echo "Backend image hash: $BACKEND_IMAGE_HASH"
  echo "Frontend image hash: $FRONTEND_IMAGE_HASH"
}

# Function to load Docker images into Kind cluster
load_images() {
  echo "Loading Docker images into Kind cluster: $CLUSTER_NAME"
  kind load docker-image perplexica-backend:$VERSION --name $CLUSTER_NAME
  kind load docker-image perplexica-frontend:$VERSION --name $CLUSTER_NAME
}

# Function to delete old Docker images from local Docker
delete_old_local_images() {
  echo "Checking and deleting old Docker images from local Docker"
  BACKEND_IMAGES=$(docker images perplexica-backend --format "{{.ID}}")
  FRONTEND_IMAGES=$(docker images perplexica-frontend --format "{{.ID}}")

  if [[ $(echo "$BACKEND_IMAGES" | wc -l) -gt 1 ]]; then
    echo "$BACKEND_IMAGES" | grep -v "$BACKEND_IMAGE_HASH" | xargs docker rmi || true
  fi

  if [[ $(echo "$FRONTEND_IMAGES" | wc -l) -gt 1 ]]; then
    echo "$FRONTEND_IMAGES" | grep -v "$FRONTEND_IMAGE_HASH" | xargs docker rmi || true
  fi
}

# Function to check and delete old Docker images from Kind nodes
delete_old_images_from_kind() {
  echo "Checking and deleting old Docker images from Kind nodes"
  for node in $(kind get nodes --name $CLUSTER_NAME); do
    BACKEND_IMAGES=$(docker exec $node crictl images | grep perplexica-backend)
    FRONTEND_IMAGES=$(docker exec $node crictl images | grep perplexica-frontend)

    BACKEND_IMAGE_COUNT=$(echo "$BACKEND_IMAGES" | wc -l)
    FRONTEND_IMAGE_COUNT=$(echo "$FRONTEND_IMAGES" | wc -l)

    if [[ $BACKEND_IMAGE_COUNT -gt 1 ]]; then
      CURRENT_BACKEND_HASH=$(echo "$BACKEND_IMAGES" | awk '{print $3}' | grep -v "$BACKEND_IMAGE_HASH")
      for HASH in $CURRENT_BACKEND_HASH; do
        echo "Deleting old backend image with hash $HASH from node $node"
        docker exec $node crictl rmi $HASH || true
      done
    fi

    if [[ $FRONTEND_IMAGE_COUNT -gt 1 ]]; then
      CURRENT_FRONTEND_HASH=$(echo "$FRONTEND_IMAGES" | awk '{print $3}' | grep -v "$FRONTEND_IMAGE_HASH")
      for HASH in $CURRENT_FRONTEND_HASH; do
        echo "Deleting old frontend image with hash $HASH from node $node"
        docker exec $node crictl rmi $HASH || true
      done
    fi
  done
}

# Function to redeploy services
redeploy_services() {
  echo "Deleting existing pods"
  kubectl delete pod -l app=searxng || true
  kubectl delete pod -l app=perplexica-backend || true
  kubectl delete pod -l app=perplexica-frontend || true

  echo "Deploying searxng service"
  kubectl apply -f ./perplexica-k8s/searxng-deployment.yaml

  echo "Deploying perplexica-backend service"
  kubectl apply -f ./perplexica-k8s/backend-deployment.yaml

  echo "Deploying perplexica-frontend service"
  kubectl apply -f ./perplexica-k8s/frontend-deployment.yaml

}

# Main function to build, load, and redeploy
main() {
  build_images
  load_images
  delete_old_local_images
  delete_old_images_from_kind
  redeploy_services

  echo "Redeployment completed successfully"
}

# Run the main function
main

