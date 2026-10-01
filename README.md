# Todo Summary Assistant — DevOps delivery

This repository contains the Todo Summary Assistant application and the DevOps deliverables for the assignment. The application is a React UI plus a Java 17/Spring Boot REST API, MySQL persistence, Cohere summarization, and Slack webhook integration.

## Requirements

- Git
- JDK 17+ and Maven (or a Maven installation on your PATH)
- Node.js 20+ and npm
- MySQL 8 reachable from the backend
- Docker for image builds
- Jenkins with Git, Java/Maven, Node/npm, Docker access, and a registry credential for CI
- Kubernetes and `kubectl`; Flux or Argo CD for GitOps deployment

Cohere and Slack credentials are needed only for those integrations. AWS/EKS is optional.

## Local development

Create a MySQL database named `todo_db`. Run the backend from the repository root (PowerShell shown):

```powershell
$env:SPRING_DATASOURCE_URL = 'jdbc:mysql://localhost:3306/todo_db?createDatabaseIfNotExist=true'
$env:SPRING_DATASOURCE_USERNAME = 'your_db_user'
$env:SPRING_DATASOURCE_PASSWORD = 'your_db_password'
$env:COHERE_API_KEY = 'your_cohere_key'
$env:SLACK_WEBHOOK_URL = 'your_slack_webhook'
cd Backend/todo-summary-assistant
mvn spring-boot:run
```

In a second terminal:

```powershell
cd Frontend/todo
npm ci
npm start
```

Open `http://localhost:3000`. The React app calls `http://localhost:8080/api` by default in local development. Never commit real credentials or a populated `.env` file.

## Configuration

The backend reads `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `COHERE_API_KEY`, and `SLACK_WEBHOOK_URL` from its environment. Optional settings include `SPRING_JPA_SHOW_SQL` and `SPRING_WEB_CORS_ALLOWED_ORIGINS`. The frontend reads `REACT_APP_API_BASE_URL` at build time; it defaults to `http://localhost:8080/api` locally and should be `/api` for the container deployment.

Kubernetes non-secret values are in `k8s/configmap.yaml`. Provision the `todo-secrets` Secret outside Git, preferably through a cloud/external secret manager. `k8s/secret.example.yaml` is a documentation template only and must not be applied with placeholder values or real secrets committed to Git.

## Containers

Build from the repository root:

```sh
docker build -f Dockerfile.backend -t todo-backend:local .
docker build -f Dockerfile.frontend --build-arg REACT_APP_API_BASE_URL=/api -t todo-frontend:local .
```

Both Dockerfiles use multi-stage builds and run the final process without root privileges. `.dockerignore` excludes credentials, dependency/build output, and Git metadata. The frontend image uses unprivileged NGINX to serve the React build and proxy `/api/` traffic to the backend Service.

## Jenkins CI

The root `Jenkinsfile` checks out Git, runs Maven `clean verify`, builds the frontend, builds both container images, and pushes immutable 12-character Git SHA tags. Configure a Jenkins registry credential with ID `container-registry-credentials`, set `IMAGE_NAMESPACE` to your registry namespace, and run a Linux agent with Maven/JDK 17, Node/npm, Docker CLI/daemon access. Jenkins does not deploy to Kubernetes.

## Kubernetes and GitOps

Manifests and a Kustomize entry point are in `k8s/`. Before reconciliation, set the registry/image SHA in the Deployment manifests, database host/port/name in the ConfigMap, and domain/TLS values in the Ingress. Create `todo-secrets` securely out of band. Apply to a test cluster only after validating the rendered manifests and confirming a MySQL service is reachable.

Install Flux or Argo CD and configure it to reconcile `./k8s`. CI publishes an image; a reviewed Git commit changes the image SHA in the manifests; the GitOps controller applies that desired state. Rollback by reverting the Git commit and letting the controller reconcile the previous image/configuration. Do not add direct cluster deployment to Jenkins.

## Assumptions and operational notes

- MySQL is external to Kubernetes and is independently backed up/managed.
- Ingress controller and TLS certificate provisioning are provided by the cluster operator.
- Spring Boot Actuator supplies the configured Kubernetes readiness/liveness probes.
- Secrets are injected out of band. Kubernetes Secret values are base64-encoded, not encrypted by default.
- The sample resource requests/limits and two replicas are starting values; tune them using load and service objectives.
- AWS/EKS is optional. If used, document network layout, IAM access, and cluster architecture without committing access keys.

See [FAILURE_AND_ROLLBACK.md](FAILURE_AND_ROLLBACK.md), [MONITORING_AND_OPERATIONS.md](MONITORING_AND_OPERATIONS.md), and [gitops/README.md](gitops/README.md) for the required operational deliverables.
