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

        // stage('Terraform Init') {
        //     steps {
        //         sh 'terraform init'
        //     }
        // }

        // stage('Terraform Validate') {
        //     steps {
        //         sh 'terraform validate'
        //     }
        // }

        // stage('Terraform Plan') {
        //     steps {
        //         sh 'terraform plan -out=tfplan'
        //     }
        // }

        // stage('Terraform Apply') {
        //     steps {
        //         script {
        //             try {
        //                 input message: 'Approve infrastructure changes?'
        //                 sh 'terraform apply tfplan'

        //                 // Now the cluster exists, update kubeconfig
        //                 sh '''
        //                 aws eks update-kubeconfig \
        //                 --region eu-west-1 \
        //                 --name my-eks-cluster
        //                 '''
        //             } catch (err) {
        //                 echo "Terraform Apply stage aborted or failed: ${err}"
        //                 currentBuild.result = 'ABORTED'
        //                 error("Pipeline aborted during Terraform Apply.")
        //             }
        //         }
        //     }
        // }

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
