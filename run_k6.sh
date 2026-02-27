#!/bin/bash

echo "Ustad, where are you testing?"
echo "1) Local (Port 8000)"
echo "2) K8s (Port 80)"
read -p "Select environment (1 or 2): " env_choice

if [ "$env_choice" == "1" ]; then
    export BASE_URL="${BASE_URL:-http://localhost:8000}"
elif [ "$env_choice" == "2" ]; then
    export BASE_URL="${BASE_URL:-http://localhost:80}"
else
    echo "Kya miya! 1 ya 2 select karo na!"
    exit 1
fi

echo ""
echo "Which load do you want to generate?"
echo "1) Healthy Load (200 requests/min, Biryani and Chai)"
echo "2) Error Mixed Load (150 requests/min, Pizza/Pasta/Coffee + Biryani/Chai)"
read -p "Select load option (1 or 2): " load_choice

if [ "$load_choice" == "1" ]; then
    echo "Starting Healthy Load on $BASE_URL..."
    k6 run k6_scripts/healthy_load.js
elif [ "$load_choice" == "2" ]; then
    echo "Starting Error Mixed Load on $BASE_URL..."
    k6 run k6_scripts/error_load.js
else
    echo "Kya miya! 1 ya 2 select karo na!"
fi
