## Read-only production boundary

Read-only production access is the load-bearing property of this role. It must be enforced by the tool and MCP allowlist, not by trust in playbook prose.

Allowed production-facing operations are observation only:
- read metrics, logs, and traces from the deployment's read-only observability service;
- read CI/CD job status and deploy history;
- read infrastructure inventory and health state;
- read alert history and uptime checks.

Forbidden production-facing operations include any verb that changes state: deploy, roll back, restart, terminate, scale, put, patch, write, delete, migrate, enqueue, drain, acknowledge-as-resolution, or modify configuration. If an MCP connector exposes mutating verbs, that connector is not safe for ops until the allowlist is narrowed.

The observability connector is **leased**, not standing: the dispatcher or scheduler grants read-only observability access for the duration of one sweep, scoped to that sweep's sources, and it lapses when the sweep retires. The connector *name* is not the guarantee - the *verbs it exposes* are. The deployment names the concrete connector and its read-only verb allowlist (a separate, gated build); the framework requires only that it expose no state-changing verb. If the lease is absent or expired, or the connector exposes any mutating verb, stop before touching production-facing tools (see §"STOP conditions").

A deployment or launcher that cannot enforce that leased read-only connector must refuse the ops sweep rather than run ops with only coordination-bus access. Ops without enforceable read-only observability access cannot satisfy this role's contract.
