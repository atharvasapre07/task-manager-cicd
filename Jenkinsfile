pipeline {
    agent any

    environment {
        IMAGE              = 'atharvasapre03/task-manager'
        AWS_DEFAULT_REGION = 'ap-south-1'
        STACK              = 'task-manager-stack'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                echo "Building commit ${env.COMMIT}"
            }
        }

        stage('Test') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -q -r requirements-dev.txt
                    python -m pytest -v
                '''
            }
        }

        stage('Build') {
            steps {
                sh 'docker build --build-arg GIT_COMMIT=$COMMIT -t $IMAGE:$COMMIT -t $IMAGE:latest .'
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push $IMAGE:$COMMIT
                        docker push $IMAGE:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
                        SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC --query "Subnets[*].SubnetId" --output text | tr '\\t' ',')

                        aws cloudformation deploy \
                          --template-file infra/infra.yaml \
                          --stack-name $STACK \
                          --capabilities CAPABILITY_IAM \
                          --no-fail-on-empty-changeset \
                          --parameter-overrides VpcId=$VPC SubnetIds=$SUBNETS ImageUrl=docker.io/$IMAGE:$COMMIT DesiredCount=1

                        aws ecs wait services-stable --cluster tm-cf-cluster --services tm-cf-service

                        TASK=$(aws ecs list-tasks --cluster tm-cf-cluster --service-name tm-cf-service --query "taskArns[0]" --output text)
                        ENI=$(aws ecs describe-tasks --cluster tm-cf-cluster --tasks $TASK --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
                        IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query "NetworkInterfaces[0].Association.PublicIp" --output text)
                        echo "Deployed commit $COMMIT. App URL: http://$IP:8080"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
    }
}
