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

        stage('Terraform Apply') {
            steps {
                input message: 'Approve infrastructure changes?'
                sh 'terraform apply tfplan'
            }
        }
    }

    post {
        failure {
            echo 'Terraform deployment failed.'
        }
        success {
            echo 'Infrastructure deployed successfully.'
        }
    }
}
