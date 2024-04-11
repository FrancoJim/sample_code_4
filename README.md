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

## Prerequisites

- AWS CLI and configured AWS account access
- Terraform installed
- kubectl installed and configured
- Helm installed
- Docker installed

### Automation Scripts

Two scripts automate the setup and deployment process:

- `setup.sh`: Sets up the Kubernetes cluster and installs Jenkins.
- `deploy_microservice.sh`: Triggers the microservice deployment pipeline in Jenkins.

To run the setup script:

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

To deploy the microservice:

```bash
./scripts/deploy_microservice.sh
```

To clean up the resources:

```bash
./scripts/cleanup_destroy.sh
```

## Usage

After deployment, the microservice will be accessible through the Kubernetes service URL. You can get the service's external IP using:

```bash
kubectl get svc weather-service
```

## License

[MIT](LICENSE)

- [Choose an open source license | Choose a License](https://choosealicense.com/)
