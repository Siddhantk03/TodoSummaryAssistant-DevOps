# Failure and rollback procedures

## Faulty version in production

Revert the Git commit that changed the production image tag/configuration, review and merge the revert, and let Flux/Argo CD reconcile. Confirm rollout completion, readiness, and key user flows. Keep immutable image tags so the prior image remains available. For urgent mitigation, use the controller's rollback/suspend procedure, then commit the corresponding desired state to Git.

## Application crashes after deployment

Kubernetes restarts a container that exits. Liveness failures restart unhealthy containers; readiness failures remove pods from Service endpoints while leaving them available for recovery. The Deployment maintains two replicas, but service continuity still depends on spare node capacity and healthy dependencies. Check `kubectl describe pod`, events, previous container logs, resource pressure, database connectivity, probe failures and secret references. If the rollout cannot become healthy, revert the Git change and let GitOps restore the prior image/configuration.

## Jenkins is down

Already-built immutable images and GitOps reconciliation continue to work; Jenkins is only the build/publish path. Pause new releases until CI is restored or use a documented, authorized alternate builder with equivalent tests and provenance. Do not bypass review or push unverified tags.

## Secrets are leaked

Immediately revoke/rotate the exposed credential at its issuer (including Cohere, Slack, database, registry or cloud), update the external secret store, and restart/reconcile workloads. Identify exposure scope and access logs, remove leaked values from Git history where possible, notify the security owner, and check for unauthorized use. Rotation is required even after deleting the visible value from Git.

## Kubernetes node fails

The control plane marks the node unavailable; after Kubernetes eviction timing, it schedules eligible pods onto healthy nodes if capacity and placement constraints permit. The two app replicas and readiness-aware Services help preserve availability, but do not guarantee it if the remaining nodes lack capacity. Check node conditions, cluster events, autoscaler/managed-node-group activity, pod scheduling, and volume attachment. Replace or repair the failed node and verify all replicas return to Ready. The external MySQL service needs its own HA, backup and recovery plan; EKS does not recover that database for you.
