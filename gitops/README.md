# GitOps deployment flow

Install Flux or Argo CD in the cluster with read-only access to this repository and configure it to reconcile `k8s/` (or a production overlay in `gitops/overlays/production`). The controller, not Jenkins, applies manifests.

1. Jenkins builds/tests and pushes immutable images tagged with the Git commit SHA.
2. A reviewed Git change updates the image tags in the environment overlay.
3. Flux/Argo CD detects the commit and reconciles the cluster. Readiness probes and rollout status gate service traffic.
4. To roll back, revert the image-tag/configuration commit and merge the revert. The controller restores the previous desired state.

For production, use a separate protected environment repository or protected branch, require review, and use an image updater or reviewed automation to open the tag-update change. Keep secret values in an external secret manager; commit only ExternalSecret references or encrypted manifests.

Initial bootstrap example (Flux): `flux bootstrap github ...`, then create a GitRepository and Kustomization pointing at `./k8s`. Bootstrap credentials must be provisioned securely and never committed.
