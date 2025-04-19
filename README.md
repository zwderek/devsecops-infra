# DevSecOps Infra

### In EC2
sudo apt update
sudo apt install -y docker.io docker-compose

sudo usermod -aG docker $USER
newgrp docker

docker network create devsecops-net