#!/bin/bash
set -e

CLUSTER_NAME="cncf-hyd"
PORT="80"

echo "Creating k3d cluster: $CLUSTER_NAME..."
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster $CLUSTER_NAME already exists."
else
    k3d cluster create "$CLUSTER_NAME" -p "$PORT:80@loadbalancer" --agents 3
fi

echo "Applying namespaces..."
kubectl apply -f namespaces.yaml

echo "Done! Ingress will be accessible at http://localhost:$PORT"
