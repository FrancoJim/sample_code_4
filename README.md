# sample_code_4

**Microservice Deployment Project**

- The project demonstrates:
  - Setting up a Kubernetes cluster using Terraform.
  - Deploying Jenkins for CI/CD.
  - Running a microservice that provides current weather information for Washington, DC.
- Project structure includes:
  - Terraform configurations for cloud infrastructure setup.
  - A Dockerized Python Flask application for the microservice.
  - Kubernetes deployment configurations.
  - Automation scripts.

## Workflow Diagram

```mermaid
graph TD;
    A[AWS] -->| | B[Kubernetes];
    B --> C{Jenkins CI/CD};
    B --> D[Weather Container];
    D --> E[Weather App];
    E <-->|Fetches weather data from| F[Open Meteo API];
    C -->|1. Pulls code| G[GitHub Repository];
    G -->|2. Triggers build & deploy| C;
    C -->|3. Build| D;
    C -->|4. Deploy| D;
    E <-.->| | H[End Users];

    classDef cloud fill:#ff9,stroke:#333,stroke-width:2px;
    classDef k8s fill:#bbf,stroke:#333,stroke-width:2px;
    classDef ci fill:#f9f,stroke:#333,stroke-width:2px;
    classDef service fill:#9f9,stroke:#333,stroke-width:2px;
    classDef api fill:#9cf,stroke:#333,stroke-width:2px;
    classDef repo fill:#fc9,stroke:#333,stroke-width:2px;
    classDef users fill:#f9f,stroke:#333,stroke-width:4px,dashed;

    class A cloud;
    class B k8s;
    class C ci;
    class D service;
    class E service;
    class F api;
    class G repo;
    class H users;
```

## Automation Steps

1. Setup AWS infrastructure using Terraform.
2. Install Jenkins on the Kubernetes cluster.
3. Configure Jenkins to build and deploy the microservice.

- Manual:
  - Generate API token for Jenkins.
  - Create credentials for DockerHub.
  - Create credentials for EKS cluster.

### ToDos

- [x] Verify weather-app deployment works.
- [ ] Via Jenkins API, create API Credentials and provide to automation Bash script.
  - [x] Partially automated workaround in place.
- [ ] Via Jenkins API, configure EKS cluster credentials & DockerHub credentials.
  - Current workaround is to complete manually)
- [ ] Create deployment verification script to wait on successful Jenkins job
- [ ] At end of script, try to see if weather-app URL can be retrieved.

#### Research

- [Remote Access API](https://www.jenkins.io/doc/book/using/remote-access-api/)
  - Cannot find a way to create any credentials via the API.
- [jenkinsapi · PyPI](https://pypi.org/project/jenkinsapi/)
  - Does not have capability to create credentials.
- [Python Jenkins — Python Jenkins 1.8.0 documentation](https://python-jenkins.readthedocs.io/en/latest/index.html)
  - Documentation states it can create these artifacts, but it is very involved.

## Prerequisites

- AWS CLI and configured AWS account access
- Terraform installed
- kubectl installed and configured
- Helm installed
- Docker installed

### Automation Scripts

Prep the bash scripts for execution:

```bash
chmod +x scripts/*.sh
```

To run the setup script:

```bash
./scripts/setup.sh
```

To clean up the resources:

```bash
./scripts/cleanup_destroy.sh
```

## License

[MIT](LICENSE)

- [Choose an open source license | Choose a License](https://choosealicense.com/)
