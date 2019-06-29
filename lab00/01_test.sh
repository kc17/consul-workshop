#/bin/bash

echo "Testing Consul ..."
consul --version

echo ""
echo "Testing Consul-Template ..."
consul-template --version

echo ""
echo "Testing Docker ..."
docker --version

echo ""
echo "Testing Docker Compose ..."
docker-compose --version