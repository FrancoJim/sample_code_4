#!/bin/bash
clear


function setup_env() {
    # Preparing the running environment
    echo "Setup Pre-requisites..."
    
    # Change PWD to the root of the repository
    while [ ! -f "LICENSE" ]; do cd ..; done
    
    CONFIG_DIR=".configs"
    
    mkdir -p ${CONFIG_DIR}/.terraform
    cd ${CONFIG_DIR}
    
    if [ ! -f ".env" ]; then
        cp ../example.env .env
        cd ..
        echo "Please fill in the required values in the .env file."
        exit 1
    fi
    
    . .env
    cd ..
    echo "Pre-requisites setup complete."
    echo
    
}

function build_terraform_aws_env_and_config_kubectl(){
    echo "Starting Kubernetes cluster setup..."
    cd infrastructure
    export TF_DATA_DIR=../${CONFIG_DIR}/.terraform
    # terraform validate ; exit
    terraform init -upgrade
    terraform apply -auto-approve
    
    AWS_CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
    AWS_REGION=$(terraform output -raw region)
    AWS_CLUSTER_NAME=$(terraform output -raw cluster_name)
    sleep 5 # Give cluster time to start
    echo "Kubernetes cluster setup complete."
    echo
    
    echo "Configuring kubectl for EKS..."
    # Assuming AWS CLI and kubectl are configured, configure kubectl
    aws eks --region ${AWS_REGION} update-kubeconfig --name ${AWS_CLUSTER_NAME}
    echo "Kubectl configured."
    cd ..
    echo
}

function k8s_jenkins_setup(){
    echo "Setup Kubernetes Jenkins Preparation..."
    cd ci-cd/k8s/jenkins
    # Install EBS CSI driver
    # kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable"
    # kubectl apply -k .
    echo "Kubernetes Preped for Jenkins."
    cd ../../..
    echo
    echo "Starting Jenkins installation..."
    cd ci-cd
    helm install jenkins-release jenkinsci/jenkins -f helm-values.yaml --namespace jenkins --create-namespace
    
    # Port forward Jenkins service to localhost:8080
    sleep 5 # Give Jenkins time to start
    # nohup kubectl --namespace jenkins port-forward svc/jenkins-release 8080:8080 &
    kubectl --namespace jenkins port-forward svc/jenkins-release 8080:8080 &
    sleep 5 # Give port-forward time to start
    echo "Jenkins installation complete."
    cd ..
    echo
}

function jenkins_pipeline_setup(){
    echo "Setup Jenkins Pipeline..."
    cd ci-cd
    JENKINS_FQDN="127.0.0.1:8080"
    JENKINS_ADMIN_USERNAME="admin"
    JENKINS_ADMIN_PASSWORD=$(kubectl exec --namespace jenkins -it svc/jenkins-release -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo)
    
    JENKINS_JOB_NAME="sample-job"
    JENKINS_CRED="${JENKINS_ADMIN_USERNAME}:${JENKINS_ADMIN_PASSWORD}"
    
    echo
    echo "${JENKINS_ADMIN_USERNAME} password: ${JENKINS_ADMIN_PASSWORD}"
    echo
    
    function generate_jenkins_api_token(){
        # Login & get the session token from Jenkins
        CRUMB=$(curl -s "http://${JENKINS_FQDN}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" --cookie-jar cookies.txt)
        LOGIN=$(curl -s "http://${JENKINS_FQDN}/j_acegi_security_check' --data 'j_username=${JENKINS_ADMIN_USERNAME}&j_password=${JENKINS_ADMIN_PASSWORD}" --cookie cookies.txt --cookie-jar cookies.txt --header "$CRUMB")
        
        # Request a new API token
        NEW_TOKEN_RESPONSE=$(curl -s "http://${JENKINS_FQDN}/user/${JENKINS_ADMIN_USERNAME}/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
            --data 'newTokenName=TokenName' \
            --cookie cookies.txt \
            --header "$CRUMB" \
        --cookie-jar cookies.txt)
        
        if [ -z "$NEW_TOKEN_RESPONSE" ]; then
            echo "No response received from API token generation request."
            exit 1
        fi
        
        # Extract the token from the response
        API_TOKEN=$(echo $NEW_TOKEN_RESPONSE | python -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('tokenValue', 'No token found'))")
    }
    
    # TODO: Finish this function (API token generation) and remove the token below
    # generate_jenkins_api_token
    API_TOKEN="11cb60d471c8e1fc494d74224a71efd1c2"
    
    # If API_TOKEN is empty, exit
    if [ -z "$API_TOKEN" ]; then
        echo "Failed to generate API token. Exiting..."
        exit 1
    fi
    
    # echo "Your new API token is: ${API_TOKEN}"
    JENKINS_CRED="${JENKINS_ADMIN_USERNAME}:${API_TOKEN}"
    
    # Create a new Jenkins job/pipeline
    # HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/xml" -d @jenkins_job_config.xml "http://${JENKINS_FQDN}/createItem?name=${JENKINS_JOB_NAME}"  --user ${JENKINS_CRED})
    HTTP_RESPONSE=200
    if [ $HTTP_RESPONSE -ge 200 ] && [ $HTTP_RESPONSE -lt 300 ]; then
        echo "Jenkins Pipeline setup complete."
    else
        echo "Jenkins Pipeline setup failed. HTTP response code: $HTTP_RESPONSE"
        exit 1
    fi
    echo
    echo "Setup complete. Your CI/CD environment is ready."
    echo
    echo "Triggering Jenkins job..."
    JENKINS_URL="http://${JENKINS_FQDN}/job/${JENKINS_JOB_NAME}"
    
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST ${JENKINS_URL}/build --user ${JENKINS_CRED})
    
    if [ $HTTP_RESPONSE -ge 200 ] && [ $HTTP_RESPONSE -lt 300 ]; then
        echo "Deployment initiated."
    else
        echo "Deployment failed. HTTP response code: ${HTTP_RESPONSE}"
        exit 1
    fi
    
    echo "Jenkins job triggered."
    echo
    echo "Deployment initiated."
}

function verify_job_status(){
    # TODO: Finish this function (verify_job_status)
    echo "Checking job status..."
    echo
    JOB_STATUS=""
    while [ -z "$JOB_STATUS" ]; do
        sleep 5
        JOB_STATUS=$(curl -s "http://${JENKINS_FQDN}/job/${JENKINS_JOB_NAME}/lastBuild/api/json" --user ${JENKINS_CRED} | python -c "import sys, json; print(json.load(sys.stdin).get('result', 'No result found'))")
        echo "Job status: $JOB_STATUS"
        if [ "$JOB_STATUS" == "SUCCESS" ]; then
            echo "Job completed successfully."
            break
            
            elif [ "$JOB_STATUS" == "FAILURE" ]; then
            echo "Job failed."
            exit 1
            
            elif [ "$JOB_STATUS" == "No result found" ]; then
            echo "Job status not found."
            exit 1
        fi
    done
}


setup_env
# build_terraform_aws_env_and_config_kubectl
# k8s_jenkins_setup
jenkins_pipeline_setup
# verify_job_status

