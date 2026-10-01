# DevOps task: step-by-step guide

This guide is based on `FT-DevOps-Task (1).pdf` and the supplied Todo Summary Assistant source archive. The PDF is the assignment specification; this file translates it into an execution plan. The assignment requires Git, Maven, Docker, Jenkins CI, Kubernetes, GitOps, environment configuration, secret handling, and rollback documentation. AWS/EKS is optional.

## 1. What you need before starting

- Git and access to a GitHub repository (the assignment names `Praj122/TodoSummaryAssistant`).
- JDK 17+, Maven, Node.js/npm, Docker, and a reachable MySQL database for local development.
- A Linux Jenkins agent with Git, JDK 17/Maven, Node/npm, Docker Engine, and permission to push images to a registry.
- A container registry account and namespace. Store its credentials in Jenkins; do not put passwords or tokens in Git.
- A Kubernetes cluster, `kubectl`, and an ingress controller/TLS setup if you want external HTTP access. Keep the MySQL database reachable from the cluster.
- A Cohere API key and Slack incoming-webhook URL to use the summary and Slack features. These are secrets; use local environment variables for development and an external secret store for a real cluster.
- For GitOps, Flux or Argo CD installed/configured to read the deployment path from Git.

AWS/EKS is optional. If selected, also create the EKS cluster, networking, IAM access, and document the architecture. Do not store AWS access keys in the repository.

## 2. Understand and run the app locally

The app is a React frontend and Spring Boot Java 17 backend. The backend uses Maven, Spring Data JPA, and MySQL, and calls Cohere and Slack. Start by reviewing:

- `Backend/todo-summary-assistant/pom.xml`
- `Backend/todo-summary-assistant/src/main/resources/application.properties`
- `Frontend/todo/package.json`
- `Frontend/todo/src/services/todoService.js`

Create a local database named `todo_db`, then provide the backend configuration through environment variables (or an untracked local config file). The code currently reads the property names `cohere.api.key` and `slack.webhook.url`; Spring maps these to `COHERE_API_KEY` and `SLACK_WEBHOOK_URL`. Database properties map to `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, and `SPRING_DATASOURCE_PASSWORD`.

From the project root, run the backend in one PowerShell window:

```powershell
$env:SPRING_DATASOURCE_URL = 'jdbc:mysql://localhost:3306/todo_db?createDatabaseIfNotExist=true'
$env:SPRING_DATASOURCE_USERNAME = 'your_local_db_user'
$env:SPRING_DATASOURCE_PASSWORD = 'your_local_db_password'
$env:COHERE_API_KEY = 'your_cohere_key'
$env:SLACK_WEBHOOK_URL = 'your_slack_webhook'
cd Backend/todo-summary-assistant
./mvnw.cmd spring-boot:run
```

In another PowerShell window, run the frontend:

```powershell
cd Frontend/todo
npm ci
npm start
```

Open `http://localhost:3000` and try create/list/update/delete, summarize, and Slack delivery. The frontend API client reads `REACT_APP_API_BASE_URL`, with `http://localhost:8080/api` as the local fallback. The frontend Dockerfile builds with `/api`; NGINX proxies `/api/` to the backend Service.

**Security:** backend settings use environment placeholders, including an empty default for the database password. Set real values only in the process environment or a secret manager; never copy credentials into the properties file or sample Kubernetes Secret.

## 3. Git and README

Initialize or clone the intended GitHub repository and keep the app and DevOps files together at its root. Review the existing `README.md`; it has basic local and deployment notes. Update it with verified prerequisites, local steps, configuration names, assumptions, container build commands, Jenkins setup, GitOps flow, and known limitations. Commit the code and DevOps artifacts to a working branch, then push it.

## 4. Build and run the containers

The root contains `Dockerfile.backend`, `Dockerfile.frontend`, `.dockerignore`, and `deploy/nginx/default.conf`. They use multi-stage builds; the final images run as non-root users. After the frontend API URL change, from the repository root:

```powershell
docker build -f Dockerfile.backend -t todo-backend:local .
docker build -f Dockerfile.frontend --build-arg REACT_APP_API_BASE_URL=/api -t todo-frontend:local .
```

The backend build copies the Maven project from `Backend/todo-summary-assistant`; the frontend build copies from `Frontend/todo`. Confirm these paths remain at repository root. Do not add `.env`, credentials, build output, or local databases to the Docker context.

## 5. Jenkins CI (build/test/publish only)

The root `Jenkinsfile` checks out source, runs `mvn clean verify`, builds the React app, builds both images, and pushes commit-SHA tags. It deliberately does not run `kubectl` or deploy to the cluster.

1. Create a Jenkins pipeline job connected to the Git repository. Configure a webhook or keep the configured SCM polling trigger.
2. On the Jenkins agent, install/provide Git, Java 17, Maven, Node/npm, Docker, and Docker daemon access.
3. Add a Jenkins username/password credential with ID `container-registry-credentials` for registry pushes.
4. In `Jenkinsfile`, replace `REPLACE_WITH_REGISTRY_NAMESPACE` with the registry namespace. Keep the value non-secret.
5. Push a commit and confirm checkout, Maven tests, frontend build, image build, and push all pass. Confirm the registry contains the immutable short-SHA tags.

If the registry is not Docker Hub, also change `REGISTRY` and ensure the Jenkins credential matches that registry. Treat test reports as part of the build record.

## 6. Kubernetes manifests

The `k8s/` directory contains a namespace, ConfigMap, backend and frontend Deployments/Services, Ingress, and a Secret template. Before deployment:

1. Choose a cluster namespace and set the actual DB host/port/name in `k8s/configmap.yaml`.
2. Replace the registry namespace and image SHA placeholders in both deployment manifests with the tags Jenkins published.
3. Provision `todo-secrets` out of band from a secret manager (or securely for a disposable demo). **Do not apply `k8s/secret.example.yaml` with placeholder or real secrets, and do not commit a populated Secret.**
4. Verify that the backend accepts the environment variables and database URL in `k8s/backend.yaml`.
5. Spring Boot Actuator is included and health probe exposure is enabled in the Kubernetes ConfigMap. Confirm the endpoints respond in the target image before production rollout.
6. Set the real DNS host and TLS Secret in `k8s/ingress.yaml`. Ensure the ingress controller and certificate provisioning exist.
7. Validate the rendered manifests, then apply them to a non-production cluster and inspect rollout health:

```powershell
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
# Provision todo-secrets securely before applying the workload manifests.
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/ingress.yaml
kubectl -n todo get deployments,pods,services,ingress
kubectl -n todo rollout status deployment/todo-backend
kubectl -n todo rollout status deployment/todo-frontend
```

The manifests already include requests/limits, labels, readiness/liveness probes, and restricted container security settings. The assignment requires all these operational controls.

## 7. GitOps delivery and rollback

The `gitops/README.md` describes the required separation: Jenkins tests and publishes immutable images; a reviewed Git change updates the deployment image tag; Flux or Argo CD reconciles that desired state into Kubernetes. Configure the controller with read-only Git access and point it to `k8s/` (or a production overlay). Jenkins must not deploy directly.

To release, merge a reviewed commit changing the image SHA in Git and wait for reconciliation/healthy rollout. To roll back, revert that Git commit and merge the revert; the GitOps controller restores the prior image/configuration. Verify ready replicas and key app operations afterward.

## 8. Complete and submit

The PDF expects these repository-root deliverables:

- `README.md` — verified local run steps, dependencies, assumptions.
- `Dockerfile.backend`, `Dockerfile.frontend`, `.dockerignore` — production-oriented container builds and a brief design explanation.
- `Jenkinsfile` — SCM-triggered CI, Maven tests, frontend build, SHA-tagged image push using Jenkins credentials.
- `k8s/` — Deployments, Services, ConfigMap/Secret handling, resources, probes, labels.
- `gitops/` — Git-driven reconcile and rollback explanation.
- `FAILURE_AND_ROLLBACK.md` — answers all five scenarios in the assignment.
- `MONITORING_AND_OPERATIONS.md` — metrics, logs, alerts, and early detection design.

The last two documents already answer the required scenarios/design questions. Submit the finished GitHub repository or a ZIP of the repository, as stated in the PDF. Remove unrelated personal files and ensure no local `.env`, credentials, or real Secret data are present in a submission archive.

## 9. Supplied files and remaining configuration

This workspace contains the DevOps scaffold and app source in the expected `Backend/` and `Frontend/` paths. The API URL uses build-time configuration, credentials use environment configuration, and Actuator is included for Kubernetes probes. The core task artifacts are:

| File or directory | Purpose |
| --- | --- |
| `README.md` | Project setup and deployment notes; verify/update before submission |
| `Dockerfile.backend`, `Dockerfile.frontend`, `.dockerignore` | Container builds and context exclusions |
| `Jenkinsfile` | Jenkins CI and image publication |
| `k8s/` | Kubernetes workload/configuration manifests and Kustomize entry point |
| `gitops/README.md` | GitOps release/rollback flow |
| `FAILURE_AND_ROLLBACK.md` | Required failure scenarios |
| `MONITORING_AND_OPERATIONS.md` | Required monitoring design |
| `deploy/nginx/default.conf` | Frontend web server and API reverse proxy |
| `Backend/`, `Frontend/` | Application source extracted from the supplied ZIP |

Before a real pipeline/deployment can run, you still need your registry namespace and Jenkins credential, Git repository connection, database endpoint/credentials, Cohere key, Slack webhook, Kubernetes cluster/ingress/TLS values, and Flux/Argo CD configuration. The image tags, API URL behavior, and health probes need the preflight checks above.
