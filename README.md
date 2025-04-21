
# DevSecOps Infrastructure Setup

## 1. Prerequisites: CICD VM (EC2 Instance) Setup

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

Ensure the Jenkins Prometheus plugin is installed.

Visit the Prometheus metrics endpoint:

```
http://<EC2-Public-IP>:8080/prometheus
```

This endpoint should expose Jenkins metrics consumable by Prometheus.

---

## 4. Grafana Setup

---

## 5. SonarQube Setup

### 5.1 Docker Setup

Run:

```bash
docker-compose up -d
```

Then visit: http://<EC2-Public-IP>:9000


### 5.2 First Login & Token Setup

1. Go to `http://<EC2-Public-IP>:9000`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. Change password when asked.
4. Go to **My Account → Security**
5. Generate a new token (e.g. `jenkins-token`)
6. Copy the token. You'll need it in Jenkins.


### 5.3 Jenkins Configuration

#### 5.3.1 Install Plugin

- Go to `Manage Jenkins → Plugins → Available`
- Search for: `SonarQube Scanner`
- Install and restart Jenkins

#### 5.3.2 Add SonarQube Server

- Go to `Manage Jenkins → Configure System`
- Find the **SonarQube servers** section
- Click `Add SonarQube`
- Set:
  - **Name**: `sonarqube`
  - **Server URL**: `http://<EC2-Public-IP>:9000`
  - **Server authentication token**: Add the token you generated

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
- You'll see:
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
 - Add the following **stage** to your `Jenkinsfile` after deployment:
  ```groovy
    stage('OWASP ZAP Scan') {
      steps {
        echo "Running OWASP ZAP Scan..."
        script {
          sh '''
            docker exec owasp-zap bash -c '
              mkdir -p /zap/wrk &&           zap-baseline.py -t http://spring-petclinic-prod:8080 -r zap_report.html || true
            '
          '''
          sh '''
            mkdir -p zap
            docker cp owasp-zap:/zap/wrk/zap_report.html zap/zap_report.html
          '''
        }
      }
    }
  ```

### 6.3 Post Section to Show Report in Jenkins UI

```groovy
  post {
    success {
      publishHTML([
        reportDir: 'zap',
        reportFiles: 'zap_report.html',
        reportName: 'OWASP ZAP Report',
        keepAll: true,
        alwaysLinkToLastBuild: true,
        allowMissing: true
      ])
    }
  }
```

### 6.5 View the Report

After a successful build, go to your Jenkins job → Click the **"OWASP ZAP Report"** link on the left sidebar to view scan results.

### 6.6 Notes

- Make sure `spring-petclinic-prod` container is accessible from ZAP (they should be on the same Docker network).
- You **do not need to mount any volumes manually** since `docker cp` pulls the report out.

---

## 7. Deployment VM Setup (Production VM)

Launch a new EC2 instance to act as the production (deployment target) VM. Recommended configuration:

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
