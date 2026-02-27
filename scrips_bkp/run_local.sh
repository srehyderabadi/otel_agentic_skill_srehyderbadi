#!/bin/bash
# Local runner script

echo "Setting up python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "Starting Biryani Service on port 8001..."
PYTHONPATH=./apps PORT=8001 uvicorn biryani_service.main:app --port 8001 &
BIRYANI_PID=$!

echo "Starting Chai Service on port 8002..."
PYTHONPATH=./apps PORT=8002 uvicorn chai_service.main:app --port 8002 &
CHAI_PID=$!

echo "Starting Order Service on port 8000..."
PYTHONPATH=./apps BIRYANI_SERVICE_URL=http://localhost:8001 CHAI_SERVICE_URL=http://localhost:8002 uvicorn order_service.main:app --port 8000 &
ORDER_PID=$!

echo "All services are up ! (Press Ctrl+C to stop)"
echo "Order via: http://localhost:8000/order/biryani/chicken"
echo "Order via: http://localhost:8000/order/chai/irani"
echo "Order via: http://localhost:8000/order/pizza/veg (To see error)"

trap "echo 'Rukk miya, sab band kara!' && kill $BIRYANI_PID $CHAI_PID $ORDER_PID" EXIT
wait
