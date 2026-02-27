#!/bin/bash
echo "Building Images: Ustad, Docker container banre!"

docker build -t biryani-service:latest -f apps/biryani_service/Dockerfile .
docker build -t chai-service:latest -f apps/chai_service/Dockerfile .
docker build -t order-service:latest -f apps/order_service/Dockerfile .

echo "Importing images into k3d cluster cncf-hyd..."
k3d image import biryani-service:latest chai-service:latest order-service:latest -c cncf-hyd
