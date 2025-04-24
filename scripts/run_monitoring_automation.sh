#!/bin/bash

echo "Running DevSecOps Monitoring Automation"
echo "==========================================="

if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible is not installed. Please install it first."
    exit 1
fi

echo "Starting automated verification and deployment..."
ansible-playbook ansible/advanced/monitoring_automation.yml -v

if [ $? -eq 0 ]; then
    echo "Automation completed successfully!"
    echo "Please check monitoring_status_report.md for details"
else
    echo "Automation failed. Please check the output above for errors."
fi

echo ""
echo "Access monitoring systems:"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Jenkins: http://localhost:8080 (admin/ac43eeaa8f1d4ee4b711954faa0f2fad)"