# Introdcution

This project implements a complete DevSecOps pipeline for the **Spring Petclinic** application using Docker and modern DevOps tools. The pipeline integrates **continuous integration, delivery, security analysis, and monitoring**, all within a containerized setup. The primary CI/CD workflow is hosted on a **dedicated CI/CD Virtual Machine (VM)** that runs core services like Jenkins, SonarQube (for static code analysis), Prometheus and Grafana (for application monitoring), and OWASP ZAP (for dynamic security scanning), and our staging service, and Ansible.

Application artifacts are pulled from GitLab by Jenkins, built, tested, and analyzed in containers, and then deployed using **Ansible** to a **separate production VM**. The production VM hosts the deployed application and simulates a real-world server environment. This setup ensures that the build and test stages are isolated, while deployments happen securely through infrastructure-as-code practices.

---

## Screenshots

[screenshots folder](./screenshots/)

---

## Video Demo

[demo video](./video_link.txt)

---

## Project Structure

```plaintext
devsecops-infra/
├── ansible/                         # Contains Ansible playbooks and inventory for deploying to the production VM
│   ├── deploy.yml                   # Main Ansible playbook for deployment
│   ├── inventory.ini                # Inventory file listing target production VMs
│   └── vars.yml                     # Variables used in the Ansible playbook
├── infra/                           # Contains configuration for infrastructure services
│   ├── grafana/                     # Grafana configuration files
│   │   ├── dashboards/              # Predefined dashboard JSON files
│   │   └── provisioning/            # Provisioning config to auto-load dashboards and datasources
│   ├── jenkins/                     # Jenkins Docker setup
│   │   ├── .dockerignore            # Docker ignore file for Jenkins build
│   │   ├── Dockerfile               # Jenkins Dockerfile with pre-installed plugins
│   │   ├── Jenkinsfile              # CI/CD pipeline definition
│   │   └── plugins.txt              # List of Jenkins plugins to install
│   ├── prometheus/                  # Prometheus configuration
│   │   └── prometheus.yml           # Prometheus scrape configuration
│   ├── sonar/                       # SonarQube configuration
│   │   └── data/                    # Persistent volume for SonarQube data
│   └── zap/                         # ZAP scan related scripts and reports
├── docker-compose.yml               # Main docker-compose file to bring up the CI/CD environment
├── screenshots/                     # Saved screenshots for documentation or reporting
├── video_link.txt                   # Demo Video
├── scripts/                         # Both shell scripts and an Ansible playbook to facilitate advanced automation
├── .gitignore                      
└── README.md                       
```

---

# DevSecOps Infrastructure Setup

## 1. Prerequisites: CICD VM (EC2 Instance) Setup

Launch a new EC2 instance to act as the CICD VM. Note that in this project, we used AWS. 
Recommended configuration:

- **AMI**: Ubuntu Server 24.04 LTS
- **Instance Type**: `t3.large` or higher
- **Storage**: 30 GB
- **Security Group**:
  - TCP port 22 (SSH)
  - TCP port 8080 (Jenkins)
  - TCP port 80 (Staging Spring Boot app)
  - TCP port 9000 (SonarQube)
  - TCP port 9090 (Prometheus)
  - TCP port 3000 (Grafana)
- **Key Pair**: Use `.pem` file to enable SSH access

Install Docker and Docker Compose:

```bash
sudo apt update
sudo apt install -y docker.io docker compose
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

## 2. Launch Jenkins in CICD VM

Navigate to the Jenkins infrastructure directory:

```bash
cd ~/devsecops-infra/infra
docker compose build jenkins
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

### 2.1 Jenkins Web Configuration

1. Visit `http://<EC2-Public-IP>:8080`
2. Log in using the initial admin password
3. Install the recommended plugins
4. Generate a GitLab **Personal Access Token**
5. Add it to Jenkins:
   - Go to **Manage Jenkins > Credentials**
   - Add a new **Username with password** credential (your GitLab username and token)

### 2.2 Create Pipeline Job (Spring PetClinic)

1. Go to Jenkins Dashboard → **New Item**
2. Enter name: `spring-petclinic-pipeline`
3. Select **Pipeline**
4. In the Pipeline section:
   - **Definition**: Pipeline script
   - **Script**: Paste your complete `Jenkinsfile`
5. Save and click **Build Now**

---

## 3. Prometheus Setup

Prometheus is responsible for collecting metrics from Jenkins and exposing them for monitoring.

### 3.1 Configuration

Prometheus is configured using the file:

```bash
infra/prometheus/prometheus.yml
```

This file includes two scrape targets:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']
```

### 3.2 Jenkins Integration

- Ensure the **Prometheus plugin** is installed in Jenkins.
- Once enabled, Jenkins will expose a `/prometheus` endpoint with metrics.
- You can access this endpoint via:

```
http://<EC2-Public-IP>:8080/prometheus
```

### 3.3 Launch Prometheus

Start Prometheus with Docker Compose:

```bash
docker-compose up -d prometheus
```

Verify that the Prometheus container is running:

```bash
docker ps
```

### 3.4 Access Prometheus UI

Navigate to:

```
http://<EC2-Public-IP>:9090
```

We can explore collected metrics and try basic queries such as:

```
jenkins_job_total_duration
jenkins_queue_size_value
jenkins_executor_count_value
```

or check the health of endpoints at:

```
http://<EC2-Public-IP>:9090/targets
```
---

## 4. Grafana Setup

Grafana is used to visualize metrics collected by Prometheus through interactive dashboards.

### 4.1 Configuration

Grafana setup is located under:

```bash
infra/grafana/
```

It includes:

- **Data source provisioning**  
  `infra/grafana/provisioning/datasources/datasource.yml`  
  This configures Prometheus as the default data source:

  ```yaml
  datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true
  ```

- **Dashboard provisioning**  
  Dashboards are provisioned via:

  ```bash
  infra/grafana/provisioning/dashboards/dashboard.yml
  ```

  And corresponding dashboard JSON files are stored in:

  ```bash
  infra/grafana/dashboards/
  ```

  Including:

  - `jenkins-dashboard.json`
  - `sonarqube-dashboard.json`
  - `application-dashboard.json`
  - `devsecops-dashboard.json`

### 4.2 Launch Grafana

Start Grafana using Docker Compose:

```bash
docker-compose up -d grafana
```

### 4.3 Access Grafana

Visit:

```
http://<EC2-Public-IP>:3000/d/jenkins-metrics/
http://<EC2-Public-IP>:3000/dashboards
```

Default login credentials:

```
Username: admin
Password: admin
```

## 5. SonarQube Setup

### 5.1 Docker Setup

Run:

```bash
docker-compose up -d
```

Then visit: `http://<EC2-Public-IP>:9000`


### 5.2 First Login & Token Setup

1. Go to `http://<EC2-Public-IP>:9000`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. Change password when asked.
4. Go to **My Account → Security**
5. Generate a new token (e.g. `jenkins-token`)
6. Copy the token. We'll need it in Jenkins.


### 5.3 Jenkins Configuration

#### 5.3.1 Install Plugin

- Go to `Manage Jenkins → Plugins → Available`
- Search for: `SonarQube Scanner` (https://plugins.jenkins.io/sonar/)
- Install and restart Jenkins

#### 5.3.2 Add SonarQube Server

- Go to `Manage Jenkins → Configure System`
- Find the **SonarQube servers** section
- Click `Add SonarQube`
- Set:
  - **Name**: `sonarqube`
  - **Server URL**: `http://<EC2-Public-IP>:9000`
  - **Server authentication token**: Add the token we generated

#### 5.3.3 Add Scanner Tool

- Go to `Manage Jenkins → Global Tool Configuration`
- Find **SonarQube Scanner**
- Click `Add SonarQube Scanner`
- Set a name (e.g. `SonarScanner`)
- Select `Install automatically`

### 5.4 Update Jenkinsfile
 - Add SonarQube Analysis after Build and Test stage
  ```groovy
          stage('SonarQube Analysis') {
              steps {
                  echo "Running SonarQube Analysis..."
                  withSonarQubeEnv("${SONARQUBE_ENV}") {
                      sh './mvnw sonar:sonar -Dsonar.projectKey=spring-petclinic'
                  }
              }
          }
  ```

### 5.5 View Results

- Go to http://<EC2-Public-IP>:9000
- Click the project (e.g. `spring-petclinic`)
- We'll see:
  - Quality Gate (pass/fail)
  - Bugs, vulnerabilities, and code smells
  - Coverage (if configured)
  - Duplications

---

## 6. OWASP ZAP Setup

### 6.1 Docker Setup

Run:

```bash
docker-compose up -d
```

This starts ZAP in "idle" mode and allows Jenkins to `docker exec` into it.

### 6.2 Update Jenkinsfile
 - Add the following **stage** to `Jenkinsfile` after deployment:
  ```groovy
    stage('OWASP ZAP Scan') {
            steps {
                echo "Running OWASP ZAP Scan..."
                script {
                    sh """
                        docker exec owasp-zap bash -c '
                            cd /zap/wrk && \
                            zap-baseline.py -t http://${APP_CONTAINER}:8080 -r zap_report.html || true
                        '
                    """
                    sh """
                        mkdir -p zap
                        docker cp owasp-zap:/zap/wrk/zap_report.html zap/zap_report.html
                    """
                }
            }
        }
  ```
  - We should add this after Deploy to Local Container (Staging) Stage, Since we are testing our staging service

### 6.3 Post Section to Show Report in Jenkins UI

```groovy
   post {
        success {
            echo "Build and deployment complete. Application running on port 80."
            publishHTML([
                reportDir: 'zap',
                reportFiles: 'zap_report.html',
                reportName: 'OWASP ZAP Report',
                keepAll: true,
                alwaysLinkToLastBuild: true,
                allowMissing: true
            ])
        }
        failure {
            echo "Pipeline failed."
        }
    }
```

### 6.5 View the Report

After a successful build, go to Jenkins job → Click the **"OWASP ZAP Report"** link on the left sidebar to view scan results.

### 6.6 Notes

- Make sure `spring-petclinic-prod` container is accessible from ZAP (they should be on the same Docker network).
- We **do not need to mount any volumes manually** since `docker cp` pulls the report out.

---

## 7. Deployment VM Setup (Production VM)

Launch a new EC2 instance to act as the Production VM (deployment target). Recommended configuration:

- **AMI**: Ubuntu Server 24.04 LTS
- **Instance Type**: `t3.small` or higher
- **Storage**: 8–16 GB
- **Security Group**:
  - TCP port 22 (SSH)
  - TCP port 8080 (Spring Boot app)
- **Key Pair**: Use `.pem` file to enable SSH access

## Ansible Deployment Pipeline

- ### Step 1: Prepare Ansible Files

  In the project root, ensure the following files exist under the `ansible/` directory:

  ```
  ansible/
  ├── deploy.yml              # Main playbook to install dependencies and deploy the app
  ├── vars.yml                # Variables such as DB credentials, ports, and paths
  ├── inventory.ini           # Target VM host and SSH config
  ├── labsuser.pem            # SSH private key to connect to the production VM
  ```

  Example `inventory.ini`:

  ```
  [web]
  <EC2-Public-DNS> ansible_user=ubuntu ansible_ssh_private_key_file=/ansible/labsuser.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  ```

  ------

  ### Step 2: Share Built JAR from Jenkins

  In `docker-compose.yml`, make sure Jenkins mounts the shared folder and ansible folder:

  ```
  volumes:
    - ./shared:/shared
    - ./ansible:/ansible
  ```

  In `Jenkinsfile`, export the built JAR:

  ```
  sh 'cp target/*.jar /shared/spring-petclinic.jar'
  ```

  ------

  ### Step 3: Add Ansible Deployment Stage to Jenkinsfile

  ```
  stage('Deploy to VM with Ansible') {
      steps {
          sh 'ansible-playbook -i /ansible/inventory.ini /ansible/deploy.yml'
      }
  }
  ```

  ------

  ### Step 4: Ansible `deploy.yml` Tasks Overview

  The playbook `ansible/deploy.yml` performs the following actions on the target VM:

  1. Installs Java 17 and MySQL
  2. Initializes the MySQL root user with password authentication
  3. Creates the `petclinic` database and user
  4. Copies the built `.jar` file from controller to the target VM
  5. Kills any existing app process
  6. Starts the new app with `nohup java -jar` in the background
  7. Waits for port `8080` to confirm the app is up

  Example excerpt:

  ```
  - name: Ensure Java 17 is installed
    apt:
      name: openjdk-17-jdk
      state: present
      update_cache: yes
  
  - name: Copy .jar file to VM
    copy:
      src: "{{ jar_source_path }}"
      dest: "{{ jar_dest_path }}"
      mode: '0755'
  
  - name: Start application
    shell: |
      nohup java -jar {{ jar_dest_path }} --spring.profiles.active=mysql \
        --spring.datasource.url=jdbc:mysql://localhost:3306/{{ db_name }} \
        --spring.datasource.username={{ db_user }} \
        --spring.datasource.password={{ db_pass }} > app.log 2>&1 &
  ```

  ------

  ### Step 5: Verify Deployment

  - Visit `http://<EC2-Public-IP>:8080`
  - You should see the **Spring Petclinic** welcome page
  - Make a code change in GitLab, commit & push — Jenkins will rebuild and redeploy automatically

## 8. Advanced Automation Scripts

We provide both an Ansible playbook and shell scripts designed for environment setup, verification, and troubleshooting.


### 8.1 Ansible Playbook for Monitoring

A dedicated Ansible playbook is located under the ansible/advanced/ directory to perform automated system checks and generate a report:

```plaintext
ansible/advanced/
└── monitoring_automation.yml      # Performs full monitoring system checks and generates report
```

### 8.2 Scripts Directory

The `scripts/` folder includes helper shell scripts for system verification, debugging, and maintenance:

```plaintext
scripts/
├── run_monitoring_automation.sh   # Runs automated Ansible playbook to verify Prometheus, Grafana, Jenkins integration
├── fix_monitoring_issues.sh       # Diagnoses and fixes common container and configuration issues
├── cleanup-all.sh                 # Stops and removes all DevSecOps containers
├── generate-report.sh             # Prints the generated monitoring status report
├── init-docker-network.sh         # Creates Docker network if not already available
```
