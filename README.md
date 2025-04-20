
# DevSecOps Infrastructure Setup

## Prerequisites: EC2 Instance Setup

Install Docker and Docker Compose:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
```

Enable Docker for the current user:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Create a dedicated Docker network:

```bash
docker network create devsecops-net
```

---

## Launch Jenkins

Navigate to the Jenkins infrastructure directory:

```bash
cd ~/devsecops-infra/infra
docker compose up -d
```

Verify that the Jenkins container is running:

```bash
docker ps
```

Access the Jenkins UI:

```
http://<EC2-Public-IP>:8080
```

Retrieve the initial admin password:

```bash
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## Jenkins Web Configuration

1. Visit `http://<EC2-Public-IP>:8080`
2. Log in using the initial admin password
3. Install the recommended plugins
4. Generate a GitLab **Personal Access Token**
5. Add it to Jenkins:
   - Go to **Manage Jenkins > Credentials**
   - Add a new **Username with password** credential (your GitLab username and token)

---

## Create Pipeline Job (Spring PetClinic)

1. Go to Jenkins Dashboard → **New Item**
2. Enter name: `spring-petclinic-pipeline`
3. Select **Pipeline**
4. In the Pipeline section:
   - **Definition**: Pipeline script
   - **Script**: Paste your complete `Jenkinsfile`
5. Save and click **Build Now**

---

## Prometheus Monitoring

Ensure the Jenkins Prometheus plugin is installed.

Visit the Prometheus metrics endpoint:

```
http://<EC2-Public-IP>:8080/prometheus
```

This endpoint should expose Jenkins metrics consumable by Prometheus.
