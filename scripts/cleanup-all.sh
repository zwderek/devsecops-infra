#!/bin/bash

echo "Stopping and removing all DevSecOps containers..."

SERVICES=("jenkins" "prometheus" "grafana" "sonarqube" "owasp-zap")

for service in "${SERVICES[@]}"
do
  if docker ps -a --format '{{.Names}}' | grep -qw "$service"; then
    echo "Stopping $service..."
    docker stop "$service" >/dev/null 2>&1
    echo "Removing $service..."
    docker rm "$service" >/dev/null 2>&1
  else
    echo "$service is not running or already removed."
  fi
done

echo "Clean-up complete."
