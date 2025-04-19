# DevSecOps Infra

### In EC2
sudo apt update
sudo apt install -y docker.io docker-compose

sudo usermod -aG docker $USER
newgrp docker

docker network create devsecops-net

#### Run Junkins Container
cd ~/devsecops-infra/infra
docker-compose up -d

docker ps

Then check http://<EC2-Public-IP>:8080

Get PWD:
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
(ac43eeaa8f1d4ee4b711954faa0f2fad)