# GitOps release and rollback

Jenkins CI builds and tests the application and publishes immutable Docker images tagged with the source Git commit SHA. It does not authenticate to Kubernetes and must not run `kubectl apply` or `kubectl delete` for deployments. A reviewed Git change updates image tags in the environment manifests. Flux or Argo CD watches that Git path and reconciles the cluster to the committed desired state.

## Release flow

1. Merge source code to the configured application branch; Jenkins builds/tests and pushes `todo-backend:<12-character-SHA>` and `todo-frontend:<12-character-SHA>`.
2. An authorized maintainer updates the image tags in the deployment manifests. For EKS, the Argo example in `application.yaml` watches `k8s/overlays/eks`; for a cluster with NGINX Ingress, use `k8s/`.
3. Review and merge the image-tag commit through protected-branch review. The GitOps controller fetches the commit and applies it.
4. Confirm the new ReplicaSets become ready and the user-facing checks pass. Investigate controller events and application logs if reconciliation or readiness stalls.

Configure one reconciliation source/path per environment. Protect the branch, require review for production, and enable drift correction. Keep credentials in an external secret manager or encrypted secret mechanism; only references/templates belong in Git. The example Argo resource is a template: replace its repository URL and target branch before applying it as part of a trusted bootstrap procedure.

## Argo CD example

`application.yaml` is an Argo CD Application template for the EKS overlay. It uses the GitHub URL supplied for this project; verify that URL/branch and ensure Argo has read access before bootstrapping it through an authorized Argo CD operator. The manifest is declarative GitOps configuration; it does not provision AWS or application secrets.

## Rollback

Revert the manifest/image-tag commit, review and merge that revert, and let Flux/Argo CD reconcile the previous immutable image. Confirm the previous ReplicaSets are ready and the application works. If an emergency controller-side rollback is needed, follow the controller's approved incident procedure, then immediately record the matching desired state in Git so reconciliation does not restore the faulty version. See `../FAILURE_AND_ROLLBACK.md`.

Image tag updates may be proposed automatically, but retain a human-reviewed production merge. Do not allow an image updater or Jenkins to change live cluster state outside the protected Git path.
