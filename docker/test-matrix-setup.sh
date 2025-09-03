#!/bin/bash

# Test script for Matrix and Authelia local access

# Check if .env exists, if not, generate it
if [ ! -f .env ]; then
  echo "No .env file found. Generating one now..."
  ./generate-env.sh
fi

# Get the local IP address
LOCAL_IP=$(grep LOCAL_IP .env | cut -d= -f2)
if [ -z "$LOCAL_IP" ]; then
  LOCAL_IP="127.0.0.1"
fi

echo "=== Starting Matrix and Authelia Test Setup ==="
echo "Local IP: $LOCAL_IP"

# Stop any running containers
echo "Stopping any running containers..."
docker-compose down

# Start only required services
echo "Starting required services..."
docker-compose up -d traefik neon-postgres redis-nd authelia element conduit

# Wait for services to initialize
echo "Waiting for services to initialize (30 seconds)..."
sleep 30

# Check if services are running
echo "=== Checking Services ==="
docker-compose ps

# Test URLs
echo "=== Testing URLs ==="
echo "Testing Authelia: http://auth.localhost"
curl -I -s http://auth.localhost | head -n 1
echo

echo "Testing Matrix client: http://chat-matrix.localhost"
curl -I -s http://chat-matrix.localhost | head -n 1
echo

echo "Testing Matrix server: http://matrix.localhost"
curl -I -s http://matrix.localhost | head -n 1
echo

echo "=== Testing IP-Based Access ==="
echo "Testing Authelia via IP: http://$LOCAL_IP:9091"
curl -I -s http://$LOCAL_IP:9091 | head -n 1
echo

echo "Testing Matrix client via IP: http://$LOCAL_IP:8099"
curl -I -s http://$LOCAL_IP:8099 | head -n 1
echo

echo "Testing Matrix server via IP: http://$LOCAL_IP:6167"
curl -I -s http://$LOCAL_IP:6167 | head -n 1
echo

echo "=== Setup Complete ==="
echo "You can now access:"
echo "- Authelia: http://auth.localhost"
echo "- Element (Matrix client): http://chat-matrix.localhost"
echo "- Conduit (Matrix server): http://matrix.localhost"
echo
echo "To check logs:"
echo "docker-compose logs -f authelia"
echo "docker-compose logs -f element"
echo "docker-compose logs -f conduit"
echo
echo "To stop the test:"
echo "docker-compose down" 