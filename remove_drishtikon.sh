#!/bin/bash

set -e

CLUSTER_NAME="drishtikon"

echo "Deleting data-crawling service and deployment"
kubectl delete service data-crawling-service || true
kubectl delete deployment data-crawling || true

echo "Deleting data-analytics service and deployment"
kubectl delete service data-analytics-service || true
kubectl delete deployment data-analytics || true

echo "Deleting Elasticsearch deployment and service"
helm uninstall data-storage || true

echo "Deleting all remaining pods and services in the cluster"
kubectl delete pod --all || true
kubectl delete service --all || true

echo "All specified services, deployments, and pods have been deleted successfully."

