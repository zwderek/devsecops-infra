# DevSecOps Infra

### In EC2
sudo apt update
sudo apt install -y docker.io docker-compose

sudo usermod -aG docker $USER
newgrp docker

docker network create devsecops-net

### Run Junkins Container
cd ~/devsecops-infra/infra

docker compose up -d

docker ps

Then check http://<EC2-Public-IP>:8080

Get PWD:
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
(ac43eeaa8f1d4ee4b711954faa0f2fad)

### In Junkins Web

Generate GitLab Access Token and Add to Junkins Credentials

Create a New Job (spring-petclinic-pipeline):
    Jenkins 首页 → 点击「新建作业」
    输入名称：spring-petclinic-pipeline
    类型选择：Pipeline
    滚动到「Pipeline」配置部分：
    Definition: Pipeline script
    Script Path: 粘贴上面完整 Jenkinsfile 内容
    保存并点击「立即构建」按钮（Build Now）