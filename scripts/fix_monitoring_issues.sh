#!/bin/bash

echo "DevSecOps Monitoring Troubleshooter"
echo "======================================"

echo "Checking Prometheus container..."
if ! docker ps | grep -q prometheus; then
    echo "Prometheus container is not running"
    echo "Attempting to start Prometheus..."
    docker-compose -f infra/docker-compose.yml up -d prometheus
else
    echo "Prometheus container is running"
fi

echo "Checking Grafana container..."
if ! docker ps | grep -q grafana; then
    echo "Grafana container is not running"
    echo "Attempting to start Grafana..."
    docker-compose -f infra/docker-compose.yml up -d grafana
else
    echo "Grafana container is running"
fi

echo "Checking Jenkins container..."
if ! docker ps | grep -q jenkins; then
    echo "Jenkins container is not running"
    echo "Attempting to start Jenkins..."
    docker-compose -f infra/docker-compose.yml up -d jenkins
else
    echo "Jenkins container is running"
fi

echo "Checking Prometheus configuration..."
if [ ! -f infra/prometheus/prometheus.yml ]; then
    echo "Prometheus configuration file is missing"
    echo "Creating default configuration..."
    mkdir -p infra/prometheus
    cat > infra/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']
EOF
    echo "Restarting Prometheus with new configuration..."
    docker-compose -f infra/docker-compose.yml restart prometheus
else
    echo "Prometheus configuration exists"
fi

echo "Checking Grafana configuration..."
if [ ! -d infra/grafana/provisioning/datasources ] || [ ! -f infra/grafana/provisioning/datasources/datasource.yml ]; then
    echo "Grafana datasource configuration is missing"
    echo "Creating default datasource configuration..."
    mkdir -p infra/grafana/provisioning/datasources
    cat > infra/grafana/provisioning/datasources/datasource.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
    echo "Restarting Grafana with new configuration..."
    docker-compose -f infra/docker-compose.yml restart grafana
else
    echo "Grafana datasource configuration exists"
fi

echo ""
echo "Troubleshooting completed!"
echo "We can now run the monitoring automation script to verify everything is working"
echo "   ./scripts/run_monitoring_automation.sh"