
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'ap-south-1'
        BASE_REPO_NAME = 'devops-challenge-app'
        CLUSTER_NAME = 'devops-challenge'
        APP_NAME = 'devops-demo-app'
        PATH = "${WORKSPACE}/bin:${PATH}"
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['staging', 'production'],
            description: 'Target deployment environment'
        )
        booleanParam(
            name: 'SKIP_SECURITY_SCAN',
            defaultValue: false,
            description: 'Skip Trivy image scanning'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Custom image tag (leave empty for auto: BUILD_NUMBER)'
        )
    }
    
    stages {
        // ============================================
        // STAGE 1: Setup Tools
        // ============================================
        stage('Setup Tools') {
            steps {
                echo "Installing required tools locally"
                sh '''
                    mkdir -p bin
                    
                    #Install AWS CLI
                    if ! command -v aws &> /dev/null; then
                        echo "Installing AWS CLI..."
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -q awscliv2.zip
                        ./aws/install -i ${WORKSPACE}/aws-cli -b ${WORKSPACE}/bin
                    fi
                    
                    #Install kubectl
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        mv kubectl bin/
                    fi
                    
                    #Install Trivy
                    if ! command -v trivy &> /dev/null; then
                        echo "Installing Trivy..."
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ${WORKSPACE}/bin
                    fi
                '''
                
                script {
                    env.FINAL_IMAGE_TAG = params.IMAGE_TAG ?: "${BUILD_NUMBER}"
                    // Set ECR Repository based on environment
                    env.ECR_REPOSITORY = "${env.BASE_REPO_NAME}-${params.ENVIRONMENT}"
                    echo "Image Tag: ${env.FINAL_IMAGE_TAG}"
                    echo "ECR Repository: ${env.ECR_REPOSITORY}"
                }
                
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-creds',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    script {
                        env.AWS_ACCOUNT_ID = sh(
                            script: 'aws sts get-caller-identity --query Account --output text',
                            returnStdout: true
                        ).trim()
                        
                        env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        echo "ECR Registry: ${env.ECR_REGISTRY}"
                    }
                }
            }
        }
        
        // ============================================
        // STAGE 2: Docker Build
        // ============================================
        stage('Docker Build') {
            steps {
                echo "Building Docker image"
                sh """
                    docker build \
                        -t ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:${env.FINAL_IMAGE_TAG} \
                        -t ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:latest \
                        -f application/Dockerfile \
                        application
                """
            }
        }
        
        // ============================================
        // STAGE 3: Image Security Scan (Trivy)
        // ============================================
        stage('Security Scan') {
            when {
                not { expression { params.SKIP_SECURITY_SCAN } }
            }
            steps {
                echo "🔍 Scanning image with Trivy"
                
                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:${env.FINAL_IMAGE_TAG}
                """
            }
        }
        
        // ============================================
        // STAGE 4: Push to ECR
        // ============================================
        stage('Push to ECR') {
            steps {
                echo "Pushing image to ECR"
                
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-creds',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${env.ECR_REGISTRY}
                        
                        docker push ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:${env.FINAL_IMAGE_TAG}
                        docker push ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                    """
                }
            }
        }
        
        // ============================================
        // STAGE 5: Deploy to Kubernetes
        // ============================================
        stage('Deploy to EKS') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'production') {
                        input message: 'Deploy to Production?', ok: 'Deploy'
                    }
                }
                
                echo "Deploying to ${params.ENVIRONMENT}"
                
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-creds',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        # Update kubeconfig matched to local kubectl
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}-${params.ENVIRONMENT}
                        
                        # Apply manifests
                        kubectl create namespace ${params.ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -
                        kubectl apply -k kubernetes/manifests/${params.ENVIRONMENT}/ -n ${params.ENVIRONMENT}
                        
                        # Update image
                        kubectl set image deployment/${APP_NAME}-${params.ENVIRONMENT} \
                            ${APP_NAME}=${env.ECR_REGISTRY}/${ECR_REPOSITORY}:${env.FINAL_IMAGE_TAG} \
                            -n ${params.ENVIRONMENT}
                        
                        # Wait for rollout
                        kubectl rollout status deployment/${APP_NAME}-${params.ENVIRONMENT} -n ${params.ENVIRONMENT} --timeout=300s
                    """
                }
            }
        }
        
        // ============================================
        // STAGE 6: Verify Deployment
        // ============================================
        stage('Verify') {
            steps {
                echo "Verifying deployment"
                
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-creds',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh """
                        echo "=== Deployment Status ==="
                        kubectl get deployment ${APP_NAME}-${params.ENVIRONMENT} -n ${params.ENVIRONMENT}
                        
                        echo "=== Pods ==="
                        kubectl get pods -n ${params.ENVIRONMENT} -l app=${APP_NAME}-${params.ENVIRONMENT}
                        
                        echo "=== Service ==="
                        kubectl get svc ${APP_NAME}-${params.ENVIRONMENT} -n ${params.ENVIRONMENT}
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "Deployment successful!"
        }
        failure {
            echo "Pipeline failed!"
        }
        always {
            // Cleanup local images
            sh """
                docker rmi ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:${env.FINAL_IMAGE_TAG} || true
                docker rmi ${env.ECR_REGISTRY}/${ECR_REPOSITORY}:latest || true
            """
            cleanWs()
        }
    }
}
