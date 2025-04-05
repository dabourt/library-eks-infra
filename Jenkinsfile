pipeline {
    agent any

    environment {
        AWS_REGION = 'eu-west-1'
        TF_VAR_env = 'prod'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/dabourt/library-eks-infra.git'
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Terraform Apply Infra') {
            steps {
                script {
                    input message: 'Approve EKS infrastructure changes?'
                    sh 'terraform apply -target=module.eks_cluster -auto-approve'

                    // Ensure kubeconfig is updated after cluster is created
                    sh '''
                    aws eks update-kubeconfig \
                    --region eu-west-1 \
                    --name my-eks-cluster
                    '''
                }
            }
        }

        stage('Terraform Apply K8s Resources') {
            steps {
                script {
                    input message: 'Approve Kubernetes resource deployment?'
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                script {
                    input message: 'Are you sure you want to destroy the infrastructure?'
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    post {
        failure {
            echo 'Terraform deployment failed or was aborted.'
        }
        success {
            echo 'Infrastructure deployed successfully.'
        }
        aborted {
            echo 'Pipeline was aborted by the user.'
        }
    }
}
