# Monitoring and operations

## Metrics

- User-facing: request rate, error rate, latency percentiles, successful todo operations and summary/Slack delivery outcomes.
- JVM/API: heap and non-heap use, GC pauses, thread count, process restarts, Spring request metrics and health status.
- Kubernetes: desired/ready replicas, restart and pending counts, CPU/memory versus requests/limits, throttling, node pressure, rollout failures and ingress/TLS status.
- Dependencies: MySQL connection pool saturation, query latency/errors, Cohere and Slack request latency, rate limits and failures.

## Logs

Collect application stdout/stderr with timestamp, severity, service, version and request/correlation ID. Retain deployment/controller audit events, ingress access/error logs, pod lifecycle events, database errors and external integration failures. Redact authorization headers, API keys, webhook URLs, personal task content and other sensitive payloads. The current application may not emit structured JSON or request IDs by default; add these through logging configuration before relying on them in dashboards.

## Alerts

Page on sustained user-visible error/latency, zero ready replicas, crash loops, failed rollout, exhausted database connections, imminent resource exhaustion or node/persistent storage failure. Ticket or notify on repeated external API failures, certificate expiry, and elevated restarts. Alert on sustained symptoms with actionable thresholds and links to dashboards/runbooks; avoid paging on a single transient error, normal deploy churn, or noisy raw CPU spikes without user impact.

## Detect issues early

Use readiness/liveness probes, deployment health gates, synthetic checks for the UI and core API, dashboards, centralized logs, and periodic restore/rollback drills. Compare new-version metrics against baseline during rollout and stop/revert on a sustained regression. Track SLOs and review incidents for recurring causes.
