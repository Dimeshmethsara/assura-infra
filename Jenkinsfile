// PR-time validation only. `terraform apply` deliberately stays a manual, human-run step (see
// environments/demo/main.tf's header comment) — infra changes are infrequent and the blast
// radius of an automated bad apply is real dollars, so this pipeline never applies anything.
pipeline {
    agent { label 'terraform' }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('fmt check') {
            steps { sh 'terraform fmt -check -recursive' }
        }

        stage('validate') {
            steps {
                dir('environments/demo') {
                    sh 'terraform init -backend=false'
                    sh 'terraform validate'
                }
            }
        }

        stage('tflint') {
            steps {
                sh 'tflint --init'
                sh 'tflint --recursive'
            }
        }

        stage('Checkov') {
            steps {
                // Scans Terraform, and would also catch Dockerfile/rendered-manifest issues if
                // this pipeline were pointed at those — kept to Terraform here since the app
                // repos' own pipelines already gate their Dockerfiles via Trivy.
                sh 'checkov -d . --compact --quiet'
            }
        }

        stage('plan (posted to PR)') {
            steps {
                dir('environments/demo') {
                    // Uses the real S3/DynamoDB backend so the plan reflects actual current
                    // state — read-only, no -auto-approve anywhere in this pipeline.
                    sh 'terraform init -backend-config=backend.hcl'
                    sh 'terraform plan -no-color -out=tfplan | tee plan-output.txt'
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'environments/demo/plan-output.txt', allowEmptyArchive: true
                }
            }
        }
    }
}
