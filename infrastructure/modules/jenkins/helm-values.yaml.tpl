controller:
  serviceType: ClusterIP
  servicePort: 8080

  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "4096Mi"

  installPlugins:
    - kubernetes:4312.v57b_5f6cb_2e47
    - workflow-aggregator:600.vb_57cdd26fdd7
    - git:5.5.2
    - configuration-as-code:1932.v2f3f6d896b_d3
    - job-dsl:1.90
    - docker-workflow:580.vc7c9a_c012e05
    - kubernetes-cli:1.12.1
    - aws-credentials:231.v08a_59f17d742

  # Mount the DockerHub K8s secret into the Jenkins pod.
  # JCasC reads values from /run/secrets/additional/<secret-name>-<key>.
  additionalExistingSecrets:
    - name: jenkins-dockerhub
      keyName: username
    - name: jenkins-dockerhub
      keyName: password

  JCasC:
    defaultConfig: true
    overwriteConfiguration: true
    configScripts:

      global-env: |
        jenkins:
          globalNodeProperties:
            - envVars:
                env:
                  - key: AWS_REGION
                    value: "${aws_region}"
                  - key: EKS_CLUSTER_NAME
                    value: "${cluster_name}"

      # Credentials are sourced from the mounted K8s secret — no plain-text
      # values in the Helm release or JCasC config.
      credentials: |
        credentials:
          system:
            domainCredentials:
              - credentials:
                  - usernamePassword:
                      scope: GLOBAL
                      id: dockerhub-credentials
                      username: $${readFile:/run/secrets/additional/jenkins-dockerhub-username}
                      password: $${readFile:/run/secrets/additional/jenkins-dockerhub-password}
                      description: "DockerHub credentials"

      # Job DSL seeds the pipeline job on first boot. The job polls SCM every
      # 5 minutes; swap for a webhook trigger in production.
      pipeline-job: |
        jobs:
          - script: |
              pipelineJob('weather-service-deploy') {
                description('Build, test, and deploy the weather-service microservice')
                definition {
                  cpsScm {
                    scm {
                      git {
                        remote { url('${github_repo_url}') }
                        branches('*/main')
                      }
                    }
                    scriptPath('ci-cd/Jenkinsfile')
                  }
                }
                triggers {
                  scm('H/5 * * * *')
                }
              }

serviceAccount:
  create: true
  name: "${sa_name}"
  annotations:
    eks.amazonaws.com/role-arn: "${irsa_role_arn}"

persistence:
  enabled: true
  storageClass: gp2
  size: 10Gi

rbac:
  create: true
  readSecrets: true
