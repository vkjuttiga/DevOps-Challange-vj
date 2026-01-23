# Manual Setup Guide

This guide details the **manual steps** required to set up the environment on an Ubuntu server and configure Jenkins.

---

## Part 1: Ubuntu Server Setup

Follow these steps one by one on your Ubuntu machine (EC2 or local).

### 1. System Update & Dependencies
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl unzip wget apt-transport-https gnupg lsb-release
```

### 2. Install Docker
```bash
# Install Docker
sudo apt install -y docker.io docker-compose

# Add your user to docker group (avoids using sudo for docker commands)
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Install AWS CLI (v2)
```bash
snap install aws-cli --classic

# Verify
aws --version
```

### 4. Install Terraform
```bash
# Add HashiCorp GPG key
snap install terraform --classic

# Verify
terraform --version
```

### 5. Install kubectl
```bash
snap install kubectl --classic

# Verify
kubectl version --client
```

### 6. Install Helm (Required for ALB Controller)
```bash
snap install helm --classic
```

### 7. Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region name: ap-south-1
# Default output format: json
```

---

## Part 2: Jenkins Setup

### 1. Start Jenkins
Run Jenkins using the provided Docker Compose file:
```bash
cd jenkins
docker-compose up -d
```

### 2. Unlock Jenkins
Get the initial admin password to log in:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
*   Open browser: `http://<your-server-ip>:8080`
*   Paste the password.

### 3. Install Plugins
Select **"Install Suggested Plugins"**.
After that finishes, go to **Manage Jenkins > Plugins > Available Plugins** and install:
*   **Docker Pipeline**
*   **Pipeline: AWS Steps** (if not already installed)
*   **CloudBees AWS Credentials**

### 4. Configure AWS Credentials
1.  Go to **Manage Jenkins > Credentials > System > Global credentials**.
2.  Click **Add Credentials**.
3.  **Kind**: `AWS Credentials`
4.  **ID**: `aws-creds` (Matches the Jenkinsfile)
5.  **Access Key ID**: Your AWS Access Key.
6.  **Secret Access Key**: Your AWS Secret Key.
7.  Click **Create**.

### 5. Create Infrastructure Pipeline
This pipeline uses Terraform to provision EKS, VPC, and ECR.

1.  Go to **New Item**.
2.  Enter name: `devops-challenge-infra`.
3.  Select **Pipeline** -> **OK**.
4.  Scroll to **Pipeline Definition**:
    *   Select **Pipeline script from SCM**.
    *   **SCM**: Git.
    *   **Repository URL**: `https://github.com/YourUsername/devops-challenge.git` (Update this).
    *   **Script Path**: `jenkins/Jenkinsfile`
5.  Click **Save**.

### 6. Create Application Pipeline
This pipeline builds the app, pushes to ECR, and deploys to EKS.

1.  Go to **New Item**.
2.  Enter name: `devops-challenge-app`.
3.  Select **Pipeline** -> **OK**.
4.  Scroll to **Pipeline Definition**:
    *   Select **Pipeline script from SCM**.
    *   **SCM**: Git.
    *   **Repository URL**: `https://github.com/YourUsername/devops-challenge.git` (Update this).
    *   **Script Path**: `jenkins/Jenkinsfile.app`
5.  Click **Save**.

---

## Part 3: How to Trigger

### 1. Trigger Infrastructure
*   Click **Build with Parameters** on `devops-challenge-infra-provision`.
*   **ENVIRONMENT**: Select `staging` or `production`.
*   **RUN_TERRAFORM**: Check this to run `plan` and `apply`.
*   Click **Build**.
*   **Note**: The first run creates the cluster. It may take ~15-20 minutes.

### 2. Trigger Application
*   **Prerequisite**: Infrastructure pipeline must have run successfully (ECR & EKS must exist).
*   Click **Build with Parameters** on `devops-challenge-app-deploy`.
*   **ENVIRONMENT**: Select `staging` or `production`.
*   **IMAGE_TAG**: (Optional) Leave empty to use Build Number, or specify a tag.
*   Click **Build**.

