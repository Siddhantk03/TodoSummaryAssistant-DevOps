# Task implementation guide

The assignment PDF is the specification. This guide points to the implementation instructions for the supplied Todo Summary Assistant source.

- Follow [`DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md) for ordered local, Jenkins CI, Kubernetes, GitOps, optional AWS EKS, validation, and rollback steps.
- Read [`README.md`](README.md) for runtime prerequisites, app configuration, Docker design, repo layout, and assumptions.
- Read [`aws/README.md`](aws/README.md) before provisioning optional AWS resources. Terraform provisions only the EKS network/cluster/node group; the database, Jenkins, ingress controller, secrets and DNS are separate prerequisites.
- Read [`gitops/README.md`](gitops/README.md) for the separation between Jenkins image publishing and controller-based Kubernetes reconciliation.
- Read [`FAILURE_AND_ROLLBACK.md`](FAILURE_AND_ROLLBACK.md) and [`MONITORING_AND_OPERATIONS.md`](MONITORING_AND_OPERATIONS.md) for required operational procedures.

The PDF requirements take priority over this guide. In particular, Jenkins must not deploy by invoking `kubectl apply` or `kubectl delete`; a reviewed Git commit changes the desired image/configuration and Flux or Argo CD reconciles it. AWS/EKS is an optional preferred hosting route. Never commit real credentials, populated `.env` files, cloud access keys, Terraform state, or a live Kubernetes Secret.
