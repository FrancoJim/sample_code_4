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
        # TODO: Determine if this is needed anymore.
        # echo "Please fill in the required values in the .env file."
        # exit 1
    fi
    
    # . .env
    cd ..
    echo "Pre-requisites setup complete."
    echo
    
}

function build_terraform_aws_env_and_config_kubectl(){
    echo "Starting Kubernetes cluster setup..."
    cd infrastructure
    export TF_DATA_DIR=../${CONFIG_DIR}/.terraform
    # terraform validate ; exit
    # terraform graph ; exit

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
    
    kubectl delete ns jenkins
    
    
    # Install EBS CSI driver
    kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable"
    kubectl apply -k .
    echo "Kubernetes Preped for Jenkins."
    cd ../../..
    echo
    echo "Starting Jenkins installation..."
    cd ci-cd
    
    # helm uninstall jenkins-release -n jenkins
    helm install jenkins-release jenkinsci/jenkins -f helm-values-docker.yaml -n jenkins #--create-namespace
    
    # Port forward Jenkins service to localhost:8080
    portForwardReady=0
    
    while [ $portForwardReady -eq 0 ]; do
        kubectl -n jenkins port-forward svc/jenkins-release 8080:8080 >/dev/null 2>&1 &
        PID=$!
        
        # Wait a bit to see if the port-forward command stays up
        sleep 5
        
        if kill -0 $PID 2>/dev/null; then
            echo "Port-forwarding setup successfully."
            portForwardReady=1
        else
            echo "Jenkins not ready yet. Retrying..."
            sleep 5
        fi
    done
    
    echo "Jenkins installation complete."
    cd ..
    echo
}

function jenkins_pipeline_setup(){
    echo "Setup Jenkins Pipeline..."
    cd ci-cd
    JENKINS_FQDN="127.0.0.1:8080"
    JENKINS_ADMIN_USERNAME="admin"
    JENKINS_JOB_NAME="sample-job"
    
    until [ -n "$JENKINS_ADMIN_PASSWORD" ]; do
        sleep 5
        JENKINS_ADMIN_PASSWORD=$(kubectl exec --namespace jenkins -it svc/jenkins-release -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo)
    done
    
    JENKINS_CRED="${JENKINS_ADMIN_USERNAME}:${JENKINS_ADMIN_PASSWORD}"
    
    
    function generate_jenkins_api_token(){
        # TODO: Finish this function (API token generation)
        # [Jenkins Authentication Token-Generate Jenkins Rest Api Token - DecodingDevops](https://www.decodingdevops.com/jenkins-authentication-token-jenkins-rest-api/#Generate_Jenkins_Authentication_Token_Using_Rest_Api)
        
        CRUMB=$(curl -s "http://${JENKINS_FQDN}/crumbIssuer/api/json" \
            --user ${JENKINS_CRED} | jq -r '.crumb'
        )
        echo "Crumb: $CRUMB"
        
        if [ -z "$CRUMB" ]; then
            echo "Failed to retrieve Jenkins crumb"
            return 1
        fi
        
        # Request a new API token
        NEW_TOKEN_RESPONSE=$(curl -s "http://${JENKINS_FQDN}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
            --data 'newTokenName=AutoToken' \
            --user ${JENKINS_CRED} \
            -H "Jenkins-Crumb:${CRUMB}" \
            -H "Content-Type: application/x-www-form-urlencoded"
        )
        
        echo $NEW_TOKEN_RESPONSE
        echo $NEW_TOKEN_RESPONSE | jq -r '.data.tokenValue'
        
        if [ -z "$NEW_TOKEN_RESPONSE" ]; then
            echo "No response received from API token generation request."
            exit 1
        fi
        
        # Extract the token from the response
        API_TOKEN=$(echo $NEW_TOKEN_RESPONSE | jq -r '.data.tokenValue')
    }
    
    function manual_jenkins_api_token(){
        echo
        echo "Go to http://${JENKINS_FQDN}/manage/securityRealm/user/admin/configure"
        echo "Create an API Token."
        echo
        echo "${JENKINS_ADMIN_USERNAME} password: ${JENKINS_ADMIN_PASSWORD}"
        echo
        while [[ -z "$API_TOKEN" ]]; do
            echo "Please enter the API token for ${JENKINS_ADMIN_USERNAME}:"
            read -p "Enter API Token: " API_TOKEN
            
            if [[ -z "$API_TOKEN" ]]; then
                echo "No input provided. Please enter a valid API token."
            fi
        done
        
        if [ -z "$API_TOKEN" ]; then
            echo "Failed to generate API token. Exiting..."
            exit 1
        fi
        
    }

    function get_configure_kubectl_config(){

        SERVICE_ACCOUNT_NAME="jenkins-robot"
        SECRET_NAME="jenkins-robot-token"

        # Create a token and generate a secret for the ServiceAccount
        kubectl -n jenkins create secret generic ${SECRET_NAME} --from-literal=token=$(openssl rand -base64 32)

        # Link the secret to the ServiceAccount
        kubectl -n jenkins patch serviceaccount ${SERVICE_ACCOUNT_NAME} -p '{"secrets": [{"name": "'${SECRET_NAME}'"}]}'

        # Retrieve the name of the secret associated with the ServiceAccount
        K8S_SERVICE_ACCOUNT=$(kubectl -n jenkins get serviceaccount ${SERVICE_ACCOUNT_NAME} -o jsonpath='{.secrets[0].name}')

        # Retrieve the token from the secret and decode it
        K8S_SECRET_TOKEN=$(kubectl -n jenkins get secret ${SERVICE_ACCOUNT_NAME} -o jsonpath='{.data.token}' | base64 --decode)

        # Get Jenkins Crumb
        CRUMB=$(curl -s "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" \
            --user ${JENKINS_CRED}
        )

        # Create credential in Jenkins
        curl -X POST "${JENKINS_URL}/credentials/store/system/domain/_/createCredentials" \
        --user "${JENKINS_CRED}" \
        -H "${CRUMB}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode 'json={
              "": "0",
              "credentials": {
                "scope": "GLOBAL",
                "id": "k8s-creds",
                "secret": "'${K8S_SECRET_TOKEN}'",
                "description": "Kubernetes Cluster Authentication Token",
                "stapler-class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
              }
        }'

    }
    
    function generate_jenkins_job_config(){
        # Create a new Jenkins job/pipeline
        HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type:application/xml" --data-binary @jenkins_job_config.xml "http://${JENKINS_FQDN}/createItem?name=${JENKINS_JOB_NAME}"  --user ${JENKINS_CRED})
        
        if [ $HTTP_RESPONSE -ge 200 ] && [ $HTTP_RESPONSE -lt 300 ]; then
            echo "Jenkins Pipeline setup complete."
        else
            echo "Jenkins Pipeline setup failed. HTTP response code: $HTTP_RESPONSE"
            exit 1
        fi
        echo
        echo "Setup complete. Your CI/CD environment is ready."
        echo
    }
    
    function trigger_jenkins_job(){
        
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
        
    }
    
    
    # generate_jenkins_api_token
    manual_jenkins_api_token
    JENKINS_CRED="${JENKINS_ADMIN_USERNAME}:${API_TOKEN}"
    # get_configure_kubectl_config
    generate_jenkins_job_config

    while true; do
        echo "----------------------------------------"
        echo
        echo "Please ensure that the EKS and Docker Hub credentials are configured in Jenkins."
        echo "Go to http://${JENKINS_FQDN}/manage/securityRealm/user/admin/"
        read -n 1 -s -r -p "Press spacebar to continue" key
        
        if [ "$key" = ' ' ]; then
            echo "Continuing..."
            break
        else
            echo "You did not press the spacebar."
        fi
    done

    trigger_jenkins_job
    
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
build_terraform_aws_env_and_config_kubectl
k8s_jenkins_setup
jenkins_pipeline_setup
# verify_job_status

