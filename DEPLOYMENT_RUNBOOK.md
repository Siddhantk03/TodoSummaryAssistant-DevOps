# Implementation and deployment runbook

This runbook is a sequence for preparing CI and releasing the app through GitOps. It is not a claim that any AWS resource or deployment has already been created. Start with a non-production environment. Do not paste secrets into Git, screenshots, command history, or Jenkins console output.

## 1. Configure source and registry placeholders

1. Create Docker Hub repositories named `todo-backend` and `todo-frontend` under your account or organization. This sample assumes the images can be pulled by the cluster. If the repos are private, provision a Kubernetes registry pull Secret out of band and add its `imagePullSecrets` reference to both pod specs.
2. Edit `Jenkinsfile`: replace `REPLACE_WITH_DOCKERHUB_USERNAME_OR_ORG` with the namespace that owns the two repositories.
3. Confirm `k8s/backend.yaml` and `k8s/frontend.yaml` use the same namespace and image names. Their image tags are placeholders until a successful pipeline publishes a commit SHA.
4. Commit the configured Jenkinsfile. No registry password goes in the file.

## 2. Run locally and inspect application behavior

Requirements: Git, JDK 17, Maven 3.9+, Node.js 24 and npm, and MySQL 8. Create database `todo_db` and set these PowerShell variables to local values:

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

In a second terminal:

```powershell
Push-Location Frontend/todo
npm ci
npm start
Pop-Location
```

Open `http://localhost:3000`; API calls default to `http://localhost:8080/api`. The application context requires database connectivity. Cohere/Slack can remain empty if you do not use those features. Do not commit local `.env` files.

## 3. Build containers locally (optional before CI)

Run from repository root:

```sh
docker build -f Dockerfile.backend -t todo-backend:local .
docker build -f Dockerfile.frontend --build-arg REACT_APP_API_BASE_URL=/api -t todo-frontend:local .
```

The backend image runs on Java 17 as a non-root user. The frontend is served by an unprivileged NGINX container; `/api/` is forwarded to `todo-backend:8080` by `deploy/nginx/default.conf`. The Kubernetes frontend Service listens on port 80. Runtime configuration and credentials are injected outside the images.

## 4. Configure Jenkins CI

1. Install Jenkins on a supported Linux host. Run Jenkins itself on Java 21; install/configure JDK 17 and Maven for the backend, Node/npm for the frontend, Docker CLI/daemon, and Git. The agent must be allowed to create/remove the temporary MySQL container and build/push Docker images. Avoid giving a broadly shared host privileged Docker access.
2. Install Jenkins Git, Pipeline, Docker Pipeline, and JUnit plugins.
3. In Jenkins Credentials, create a **Username with password** credential with ID `dockerhub-credentials`. Use the Docker Hub account name and a Docker Hub access token as the password. Restrict who can use this credential.
4. Create a Pipeline job from SCM. Set the repository URL to `https://github.com/Siddhantk03/TodoSummaryAssistant-DevOps.git`, branch to `main` (or your protected source branch), and script path to `Jenkinsfile`. `pollSCM('H/5 * * * *')` checks for source changes every five minutes. Alternatively, configure a GitHub webhook to trigger the job and remove/disable polling if desired.
5. Run the job. Expected stages: checkout/tag preparation, temporary MySQL startup, Maven `clean verify`, frontend `npm ci`/tests/build, Docker image builds and registry push. A failing stage stops later stages. Maven Surefire XML reports are published by Jenkins; the temporary database and local SHA-tagged images are removed in the post action.
6. Record the successful commit's 12-character SHA. Confirm both registry tags exist: `<DOCKERHUB_NAMESPACE>/todo-backend:<SHA>` and `<DOCKERHUB_NAMESPACE>/todo-frontend:<SHA>`.

The repository currently has a Spring context load test and no frontend test files. The pipeline runs present frontend tests and allows the test command to pass when no tests have yet been added. Do not weaken tests to force a release. For a private Docker Hub repo, configure image pull credentials in Kubernetes; the sample manifests do not reference a pull Secret.

## 5. Prepare Kubernetes configuration

Choose one reconciliation path:

- Generic cluster using an NGINX Ingress controller: `k8s/`.
- AWS EKS with AWS Load Balancer Controller: `k8s/overlays/eks`.

Before GitOps sync:

1. Edit `k8s/backend.yaml` and `k8s/frontend.yaml`; replace registry namespace and `REPLACE_WITH_COMMIT_SHA` with the immutable SHA pushed by Jenkins. Keep backend/frontend image names aligned with the pipeline.
2. Edit `k8s/configmap.yaml`: set `DB_HOST` to the reachable external MySQL host, `DB_PORT` to `3306` (or configured TLS port), and `DB_NAME` to `todo_db`. For AWS use private RDS. Confirm routing, security groups, DNS and database TLS settings. Do not use `mysql.example.internal` in a real environment.
3. Provision namespace `todo` and Secret `todo-secrets` out of band. Required keys: `DB_USERNAME`, `DB_PASSWORD`, `COHERE_API_KEY`, `SLACK_WEBHOOK_URL`. For a local/test namespace only, one example command is shown below; prefer External Secrets/Secrets Manager or an approved secret manager in shared/prod clusters. Do not save this command with real values in shell history or commit the generated object:

```sh
kubectl create namespace todo
kubectl -n todo create secret generic todo-secrets \
  --from-literal=DB_USERNAME='<DB_USERNAME>' \
  --from-literal=DB_PASSWORD='<DB_PASSWORD>' \
  --from-literal=COHERE_API_KEY='<COHERE_API_KEY>' \
  --from-literal=SLACK_WEBHOOK_URL='<SLACK_WEBHOOK_URL>'
```

4. For AWS, install/configure the AWS Load Balancer Controller, set the ACM certificate ARN placeholder in `k8s/overlays/eks/kustomization.yaml`, and edit the host in `k8s/ingress.yaml`. Replace `todo.example.com` with a domain you control and create its DNS record to the provisioned ALB.
5. Inspect rendered manifests before release:

```sh
kubectl kustomize k8s
kubectl kustomize k8s/overlays/eks
```

Expected: valid YAML with two replicas each for frontend/backend, services, probes and nonzero resource requests/limits. Before applying a chosen path, the rendered images, database endpoint, host and certificate must no longer have placeholder values. The Secret is deliberately absent from rendered manifests.

## 6. Provision AWS EKS (optional)

For the EKS route, follow `aws/README.md`. In brief: configure short-lived AWS IAM access, set your trusted public CIDR in `aws/terraform/terraform.tfvars`, review Terraform plan, provision VPC/EKS/node group, and update kubeconfig. Install the load balancer controller and external secret mechanism; create RDS, DNS and ACM dependencies separately. The IaC does not create these services. Keep Terraform state private and configure remote encrypted state/locking before team use. Use IAM roles, not long-lived credentials.

## 7. Bootstrap GitOps and release

1. Install Flux or Argo CD into the cluster using its official bootstrap procedure and protected Git credentials.
2. For Argo CD, copy `gitops/application.yaml` into the Argo bootstrap configuration and verify `repoURL` and `targetRevision` match your repository. The template currently points to `https://github.com/Siddhantk03/TodoSummaryAssistant-DevOps.git` on branch `main` and watches `k8s/overlays/eks`; change `path` to `k8s` only for the generic NGINX base. Argo must be able to read the repository. Configure production branch protections and require review for tag changes.
3. Confirm the desired image tags in Git match the images published by Jenkins. Merge the reviewed release commit. The GitOps controller fetches and reconciles it; Jenkins has no Kubernetes deployment credential and does not run `kubectl apply`/`delete`.
4. Watch reconciliation and rollout:

```sh
kubectl -n todo get applications.argoproj.io
kubectl -n todo get deployments,pods,services
kubectl -n todo rollout status deployment/todo-backend --timeout=5m
kubectl -n todo rollout status deployment/todo-frontend --timeout=5m
kubectl -n todo get ingress
```

If the Argo Application CRD is not visible in the `todo` namespace, inspect it in `argocd` (`kubectl -n argocd get applications`). Expected: controller reports Synced/Healthy, both Deployments have 2/2 ready replicas, pods are Ready, and ingress has an ALB hostname (AWS) or controller address (generic cluster). The Argo example Application object itself is placed in namespace `argocd`.

5. Resolve the Ingress address and browse the configured hostname. Confirm the UI loads and basic todo flows can reach the API. Check backend logs and health endpoints when requests fail. Do not claim deployment succeeded until these checks actually pass.

## 8. Validate and rollback

Useful checks (run with correct context and access):

```sh
kubectl -n todo get pods -o wide
kubectl -n todo describe deployment todo-backend
kubectl -n todo logs deployment/todo-backend --tail=100
kubectl -n todo get events --sort-by=.lastTimestamp
```

Expected steady state: both Deployments have all desired replicas ready, no crash loops, no unresolved image-pull failures, backend can connect to MySQL, and ingress returns the frontend. If a release causes failure, revert the Git commit changing the image tags/configuration, merge the revert, and wait for GitOps reconciliation. Verify previous replicas become ready. See `FAILURE_AND_ROLLBACK.md` for incident cases and `MONITORING_AND_OPERATIONS.md` for observability.

## Placeholders to replace

Docker Hub namespace and repository names, Jenkins credential ID/registry token, immutable image SHA, trusted AWS public CIDR, AWS account/region/cluster name, RDS endpoint and database, secret values, ACM certificate ARN, DNS hostname, and any environment-specific ingress/cluster details. The GitHub repository and branch are prefilled from the URL supplied earlier; change them if you deploy from a different repository. Values in angle brackets and `REPLACE_WITH_*` strings are examples, not deployable configuration.
