# Grafana — Part 02: Alerting, Contact Points, and On-Call

---

## Grafana Alerting vs Prometheus Alerting

Both Grafana and Prometheus can fire alerts. They have different strengths:

| Feature | Prometheus Alerting | Grafana Alerting |
|---------|--------------------|--------------------|
| Configuration | YAML rules files | Grafana UI |
| Data sources | Prometheus only | Any Grafana data source |
| Multi-condition | Very powerful (PromQL) | Good (supports multiple queries) |
| Routing/grouping | Alertmanager | Grafana Notification Policies |
| Best for | Infrastructure, SLO-based | Business metrics, log-based, multi-source |

**Recommendation:** Use Prometheus alerting rules for metric-based alerts (you have more power and they work with Alertmanager). Use Grafana alerting when you need to alert on non-Prometheus data (logs, SQL queries, CloudWatch).

---

## Grafana Alerting Architecture

```
Alert Rule (PromQL/LogQL/SQL query)
       │
       ▼
Grafana Alertmanager
       │
       ▼
Notification Policy (routing tree)
       │
  ┌────┴────────────────┐
  ▼                     ▼
Contact Point        Contact Point
(Slack #alerts)    (PagerDuty)
```

---

## Creating an Alert Rule

**Via UI:** Alerting → Alert Rules → New alert rule

```
1. Define query:
   Data source: Prometheus
   Query A: sum(rate(http_requests_total{service="vault-api", status=~"5.."}[5m]))
            / sum(rate(http_requests_total{service="vault-api"}[5m]))

2. Define condition:
   IS ABOVE: 0.05     (5% error rate)

3. Alert evaluation:
   Evaluate every: 1m
   For: 5m            (must be above threshold for 5 minutes before alerting)

4. Labels and annotations:
   Labels:    severity=critical, team=backend
   Summary:   High error rate on vault-api
   Description: Error rate is {{ $values.A.Value | humanizePercentage }}

5. Notification policy: inherit from default
```

---

## Contact Points — Where to Send Alerts

Contact points are the destinations for alert notifications.

**Slack:**
```
Name: slack-alerts
Type: Slack
Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK
Channel: #alerts
Title: {{ .GroupLabels.alertname }}
Message: |
  {{ range .Alerts -}}
  **{{ .Annotations.summary }}**
  {{ .Annotations.description }}
  {{ end }}
```

**PagerDuty:**
```
Name: pagerduty-critical
Type: PagerDuty
Integration Key: YOUR_PAGERDUTY_KEY
```

**Email:**
```
Name: email-ops
Type: Email
Addresses: ops@company.com, oncall@company.com
```

**Multiple channels:** create multiple contact points and reference them in notification policies.

---

## Notification Policies — Routing Rules

```
Default policy → Slack #alerts

Specific policies (override default):
  Labels: severity=critical → PagerDuty + Slack #critical
  Labels: team=database → Slack #dba-alerts
  Labels: team=frontend → Slack #frontend-alerts
  Labels: environment=staging → Slack #staging-noise (lower priority)
```

**Grouping:** alerts with the same labels are bundled into one notification (not 50 separate messages for 50 pods down).

**Timing:**
- `Group wait`: 30s — wait for more alerts before first notification
- `Group interval`: 5m — wait this long before sending updates to an existing group
- `Repeat interval`: 4h — re-notify if alert is still firing after this time

---

## Silences — Suppress Alerts During Maintenance

```
Create a Silence:
  Labels: namespace=staging
  Duration: 2 hours
  Comment: Deploying new version, expected downtime

Effect: All alerts matching {namespace="staging"} are silenced for 2 hours.
After 2 hours, alerts resume automatically.
```

Silences are important for:
- Planned maintenance windows
- Intentional scale-down (e.g., your `signals-match-score` zero-replica case!)
- Deployments where you know there'll be a brief interruption

---

## Grafana OnCall — Incident Management

Grafana OnCall (available in Grafana Cloud and as OSS) adds on-call scheduling and escalation on top of alerting:

```
Alert fires
  → Grafana Alerting sends to OnCall
  → OnCall checks current on-call schedule
  → Pages the on-call person
  → If no ack in 15 minutes → escalate to backup
  → If still no ack → page the team lead
  → All activity logged for post-mortems
```

**Features:**
- On-call schedules (weekly rotations, overrides)
- Escalation policies
- Mobile app for push notifications
- Incident acknowledgement and resolution tracking
- Integration with Slack, PagerDuty, OpsGenie

---

## Grafana SLO — Service Level Objectives

Grafana 9+ has a native SLO feature:

Define: "99.9% of requests must return a 2xx in under 500ms"

Grafana automatically:
- Calculates the error budget (how many failures you can have in 30 days while meeting the SLO)
- Shows the burn rate (how fast you're consuming the error budget)
- Fires alerts when burn rate is too high

```
SLO: vault-api availability
  Metric: rate(http_requests_total{status!~"5.."}[5m]) / rate(http_requests_total[5m])
  Target: 99.9%
  Window: 30 days

Grafana automatically creates:
  - Error budget panel: "You've used 45% of your error budget this month"
  - Burn rate alert: "You're burning your error budget 3x faster than normal"
```

---

## Common Misunderstanding: "More alerts = better monitoring"

**The misunderstanding:** "If I alert on everything, I'll catch every problem."

**The reality:** Alert fatigue is one of the biggest problems in operations. When alerts fire constantly and most are irrelevant, oncall engineers start ignoring them. Then a real, critical alert fires — and gets ignored too. This is how companies miss real incidents.

**The right approach — alert on symptoms, not causes:**

```
BAD (cause-based, noisy):
  - CPU > 80% on any node
  - Memory > 75% on any pod
  - Disk > 60% on any volume
  These often don't impact users — just waste oncall attention

GOOD (symptom-based, actionable):
  - Error rate > 1% for 5 minutes      ← users are experiencing errors
  - P99 latency > 2s for 5 minutes     ← users notice slowness
  - Service has 0 healthy pods         ← service is down
  - Error budget burn rate is critical ← SLO will be breached
  These always mean users are impacted
```

Rule of thumb: every alert should be:
1. Actionable — there's something you can do right now
2. Urgent — it needs immediate attention
3. User-impacting — it affects your customers

If an alert doesn't meet all three, it should be a Grafana annotation or a warning, not a paging alert.

→ Continue to: `README.md`
