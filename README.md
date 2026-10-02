# Todo Summary Assistant: application and DevOps delivery

This repository packages the existing React frontend and Java 17 / Spring Boot backend with Docker, Jenkins CI, Kubernetes manifests, GitOps release guidance, and optional AWS EKS Terraform. The backend persists todos in MySQL and can call Cohere and Slack integrations. The Kubernetes examples use an external MySQL service; the AWS guide recommends managed RDS rather than running the production database in the application cluster.

## Repository contents

- `Backend/todo-summary-assistant/`: Maven Spring Boot service, REST API under `/api/todos`, and Actuator health endpoints.
- `Frontend/todo/`: Create React App frontend.
- `Dockerfile.backend`, `Dockerfile.frontend`, `.dockerignore`: multi-stage container builds.
- `Jenkinsfile`: CI build/test/publish pipeline. Jenkins publishes images; it does not deploy to Kubernetes.
- `k8s/`: base Kubernetes resources; `k8s/overlays/eks/` selects AWS Load Balancer Controller ingress settings.
- `gitops/`: Git reconciliation and rollback guidance, plus the Argo CD Application example.
- `aws/terraform/`: optional EKS/VPC infrastructure code. It does not provision application secrets or the database.
- `FAILURE_AND_ROLLBACK.md`, `MONITORING_AND_OPERATIONS.md`, `DEPLOYMENT_RUNBOOK.md`: operational procedures.

## Prerequisites

For local development: Git, JDK 17, Maven 3.9+, Node.js 24 LTS and npm, and a reachable MySQL 8 database. Docker is needed to build images. For CI, Jenkins needs Java 21 to run Jenkins, a JDK 17/Maven toolchain for the application, Node/npm, Docker CLI plus access to a Docker daemon, Git and the Jenkins Docker Pipeline and JUnit plugins. Jenkins Java runtime requirements are separate from the app's Java 17 runtime.

For Kubernetes delivery: a Kubernetes cluster, `kubectl`, Kustomize (or `kubectl kustomize`), a registry readable by cluster nodes, and Flux or Argo CD. For AWS, also use AWS CLI v2 and Terraform 1.6+, AWS IAM authorization, and EKS/AWS Load Balancer Controller prerequisites described in `aws/README.md`.

## Local development

Create a MySQL 8 database named `todo_db`, then set backend environment variables in PowerShell. Use actual values only in the local shell or a secret manager; do not commit `.env` files.

```powershell
$env:SPRING_DATASOURCE_URL = 'jdbc:mysql://localhost:3306/todo_db?createDatabaseIfNotExist=true'
$env:SPRING_DATASOURCE_USERNAME = 'your_db_user'
$env:SPRING_DATASOURCE_PASSWORD = 'your_db_password'
$env:COHERE_API_KEY = 'your_cohere_key'
$env:SLACK_WEBHOOK_URL = 'your_slack_webhook'
Push-Location Backend/todo-summary-assistant
mvn spring-boot:run
Pop-Location
```

In another terminal, start the frontend:

```powershell
Push-Location Frontend/todo
npm ci
npm start
Pop-Location
```

Open `http://localhost:3000`. The frontend's development default calls `http://localhost:8080/api`; configure `REACT_APP_API_BASE_URL` at build time for another API address. The Spring Boot process listens on 8080. Database access is required at startup. Cohere and Slack values can be empty when those integrations are not being used.

## Configuration reference

Backend environment variables consumed by Spring configuration:

| Variable | Purpose | Secret? |
| --- | --- | --- |
| `SPRING_DATASOURCE_URL` | JDBC URL, including host, database, and connection options | No, but can expose infrastructure details |
| `SPRING_DATASOURCE_USERNAME` | MySQL username | Treat as sensitive |
| `SPRING_DATASOURCE_PASSWORD` | MySQL password | Yes |
| `COHERE_API_KEY` | Cohere API key | Yes |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook | Yes |
| `SPRING_JPA_SHOW_SQL` | Optional SQL logging toggle; defaults to false | No |
| `SPRING_WEB_CORS_ALLOWED_ORIGINS` | Optional CORS origin; defaults to localhost:3000 | No |

Frontend `REACT_APP_API_BASE_URL` is compiled into the static bundle. The provided Docker build uses `/api`, which the frontend NGINX configuration proxies to the Kubernetes backend Service. Do not place secrets in React variables: browser users can inspect them.

`.env.example` files are templates only. Copy and edit them locally if useful; `.gitignore` excludes actual `.env` files. Kubernetes sensitive values are referenced by `todo-secrets`, which must be provisioned out of band; see the runbook. `k8s/secret.example.yaml` contains placeholders only and is not included in the Kustomize resources.

## Docker build and run

Build from the repository root:

```sh
docker build -f Dockerfile.backend -t todo-backend:local .
docker build -f Dockerfile.frontend --build-arg REACT_APP_API_BASE_URL=/api -t todo-frontend:local .
```

Both images use separate build and runtime stages. The backend runtime is a Java 17 JRE and runs as an unprivileged user. The frontend build uses Node 24 and serves static assets with unprivileged NGINX. The `.dockerignore` excludes Git metadata, local environment files, dependency folders, build output, and Terraform state. Configuration remains external to images. See `DEPLOYMENT_RUNBOOK.md` for local container execution and Kubernetes deployment commands.

## Jenkins CI

The root `Jenkinsfile` polls SCM every five minutes (a GitHub webhook can also trigger the job), checks out the commit, starts a temporary MySQL container for the existing Spring context test, runs Maven verification and frontend tests/build, builds two images, and pushes immutable 12-character Git SHA tags to Docker Hub. The repository currently has no frontend test files; the test stage succeeds when none are present and will run them when added. Backend JUnit XML is published by Jenkins.

Before enabling the job, replace `DOCKERHUB_NAMESPACE` in `Jenkinsfile`, create Docker Hub repositories `todo-backend` and `todo-frontend` under that namespace, and add a Jenkins username/password credential with ID `dockerhub-credentials` (password should be a Docker Hub access token). Configure a Pipeline-from-SCM job with this `Jenkinsfile`, and an agent with Java 17/Maven, Node/npm, Docker, and access to a Docker daemon. Jenkins itself should run on Java 21. Do not put registry passwords in the Jenkinsfile. See the runbook for trigger, credential and expected-stage details.

## Kubernetes and GitOps

The `k8s/` Kustomize base defines the `todo` namespace, ConfigMap, two-replica backend/frontend Deployments and ClusterIP Services, and a generic NGINX Ingress. Deployments have resource requests/limits, probes, labels, and restricted container security settings. Replace image namespace and SHA placeholders and set the external database endpoint before reconciliation. `todo-secrets` must contain `DB_USERNAME`, `DB_PASSWORD`, `COHERE_API_KEY`, and `SLACK_WEBHOOK_URL`; create it through an external secret manager or another approved out-of-band process.

Jenkins only builds, tests, and publishes immutable images. A reviewed Git commit updates image tags in the environment configuration; Flux or Argo CD observes Git and reconciles Kubernetes. Roll back by reverting that Git commit and allowing the controller to reconcile. Jenkins must not run `kubectl apply`/`delete` as a deployment mechanism. See `gitops/README.md` and `FAILURE_AND_ROLLBACK.md`.

For AWS EKS, reconcile `k8s/overlays/eks` instead of the base. That overlay changes ingress settings for AWS Load Balancer Controller and has an ACM certificate ARN placeholder. The controller, certificate, DNS record and external database must be prepared separately. Do not configure public access CIDR as `0.0.0.0/0` for the cluster API.

## AWS scope and assumptions

AWS is optional. The Terraform sample provisions an EKS cluster, a two-AZ VPC, private worker subnets, public load-balancer subnets, one NAT gateway, and a managed node group. It does not provision Jenkins, RDS, the AWS Load Balancer Controller, External Secrets, DNS, ACM certificates, application Secrets, or GitOps. The one-NAT setup reduces development cost but creates an egress availability dependency. Read `aws/README.md` before creating resources; review costs, quotas, CIDRs, IAM and version support. AWS credentials and Terraform state must stay out of Git.

## Validation commands

These are commands for you to run; they have not been run as part of preparing this package.

```sh
cd Backend/todo-summary-assistant && mvn -B clean verify
cd ../../Frontend/todo && npm ci && npm test -- --watchAll=false --passWithNoTests && npm run build
cd ../.. && docker build -f Dockerfile.backend -t todo-backend:local .
docker build -f Dockerfile.frontend --build-arg REACT_APP_API_BASE_URL=/api -t todo-frontend:local .
kubectl kustomize k8s
kubectl kustomize k8s/overlays/eks
```

Expected results: Maven exits 0 and produces Surefire reports; frontend exits 0 and emits `Frontend/todo/build/`; both Docker builds exit 0; each Kustomize command prints valid resources with the requested image/certificate placeholders still visible until configured. These checks do not prove that AWS resources were provisioned or that the app works against your database/integrations.

## Assignment deliverables

Follow `DEPLOYMENT_RUNBOOK.md` in order. The PDF is the assignment specification; AWS EKS is an optional preferred hosting path. The repository includes the Spring backend and React frontend while keeping application behavior unchanged except for deployment configuration.
