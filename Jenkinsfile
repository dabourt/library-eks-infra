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
                sh '''
                aws eks update-kubeconfig \
                --region eu-west-1 \
                --name my-eks-cluster
                '''
                script {
                    retry(2) { // Allow up to 2 retries
                        try {
                            input message: 'Approve infrastructure changes?'
                            sh 'terraform apply tfplan'
                        } catch (err) {
                            echo "Terraform Apply stage aborted or failed: ${err}"
                            currentBuild.result = 'ABORTED'
                            error("Pipeline aborted during Terraform Apply.")
                        }
                    }
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
        always {
            script {
                if (params.DESTROY_RESOURCES == true) {
                    try {
                        input message: 'Are you sure you want to destroy the infrastructure?'
                        sh 'terraform destroy -auto-approve'
                    } catch (err) {
                        echo "Terraform Destroy stage failed: ${err}"
                        error("Pipeline failed during Terraform Destroy.")
                    }
                }
            }
            echo 'Pipeline execution completed.'
        }
    }
}
