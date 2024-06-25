#!/bin/bash

set -e

echo "Deleting perplexica-backend service and deployment"
kubectl delete service perplexica-backend || true
kubectl delete deployment perplexica-backend || true

echo "Deleting perplexica-frontend service and deployment"
kubectl delete service perplexica-frontend || true
kubectl delete deployment perplexica-frontend || true

echo "Deleting searxng service and deployment"
kubectl delete service searxng || true
kubectl delete deployment searxng || true

echo "All specified services and deployments have been deleted successfully."

