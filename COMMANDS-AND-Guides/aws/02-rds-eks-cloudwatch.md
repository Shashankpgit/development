# AWS — Part 02: RDS, EKS, and CloudWatch

---

## RDS — Relational Database Service

RDS is managed databases in AWS. AWS handles: backups, patching, replication, failover. You handle: schema, queries, performance tuning.

Supported engines: PostgreSQL, MySQL, MariaDB, Oracle, SQL Server, Aurora (AWS's own MySQL/PostgreSQL-compatible engine).

### RDS Key Concepts

**Multi-AZ**: runs a standby replica in a different Availability Zone. Automatic failover in ~1-2 minutes if the primary fails. Recommended for production.

**Read Replica**: a copy of the database for read-heavy workloads. Your app reads from replicas to reduce primary load. Not for HA — read replicas are NOT automatic failover targets.

**Parameter Group**: RDS configuration settings (like postgresql.conf). Change settings through parameter groups, not by SSHing into the database server.

**Subnet Group**: defines which subnets RDS can launch into. Always use private subnets for databases.

### RDS CLI Commands

```bash
# Create a PostgreSQL RDS instance
aws rds create-db-instance \
  --db-instance-identifier vault-db-prod \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 15.3 \
  --master-username vaultadmin \
  --master-user-password "$(openssl rand -base64 32)" \
  --db-name vault \
  --vpc-security-group-ids sg-12345678 \
  --db-subnet-group-name vault-db-subnet-group \
  --backup-retention-period 7 \
  --multi-az \
  --storage-type gp3 \
  --allocated-storage 100 \
  --storage-encrypted \
  --deletion-protection

# List DB instances
aws rds describe-db-instances \
  --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]" \
  --output table

# Create a read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier vault-db-read-1 \
  --source-db-instance-identifier vault-db-prod

# Create a snapshot (manual backup)
aws rds create-db-snapshot \
  --db-instance-identifier vault-db-prod \
  --db-snapshot-identifier vault-db-snapshot-20260617

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier vault-db-restored \
  --db-snapshot-identifier vault-db-snapshot-20260617

# Modify instance (e.g., upgrade instance type)
aws rds modify-db-instance \
  --db-instance-identifier vault-db-prod \
  --db-instance-class db.t3.large \
  --apply-immediately    # without this, change happens during next maintenance window

# Delete instance (with final snapshot)
aws rds delete-db-instance \
  --db-instance-identifier vault-db-prod \
  --final-db-snapshot-identifier vault-db-final-snapshot
```

---

## EKS — Elastic Kubernetes Service

EKS is managed Kubernetes in AWS. AWS runs the control plane (API server, etcd, scheduler) — you manage the worker nodes and workloads.

### EKS Concepts

**Cluster**: the control plane + worker nodes.

**Node Group**: a group of EC2 instances that act as Kubernetes worker nodes. Managed node groups: AWS manages the EC2 instances, AMI updates, and draining. Self-managed: you manage everything.

**Fargate Profile**: run pods serverlessly — no EC2 instances to manage. AWS allocates compute per pod.

**IRSA (IAM Roles for Service Accounts)**: allows Kubernetes pods to have their own IAM role. The pod's service account is annotated with a role ARN, and the pod receives temporary AWS credentials. The proper way to give pods AWS access.

### EKS CLI Commands

```bash
# Install eksctl (EKS CLI tool — much easier than raw AWS CLI for EKS)
curl --silent --location \
  "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
  | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin

# Create a cluster (creates VPC, subnets, node groups, everything)
eksctl create cluster \
  --name vault-cluster \
  --region ap-south-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --with-oidc \
  --managed

# Configure kubectl to talk to your EKS cluster
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name vault-cluster

# Verify connection
kubectl get nodes

# List clusters
aws eks list-clusters --region ap-south-1

# Describe cluster
aws eks describe-cluster --name vault-cluster --region ap-south-1

# Create a Fargate profile (run specific pods serverlessly)
eksctl create fargateprofile \
  --cluster vault-cluster \
  --region ap-south-1 \
  --name vault-fargate \
  --namespace production

# Scale node group
aws eks update-nodegroup-config \
  --cluster-name vault-cluster \
  --nodegroup-name standard-workers \
  --scaling-config minSize=2,maxSize=10,desiredSize=5

# Delete cluster
eksctl delete cluster --name vault-cluster --region ap-south-1
```

### IRSA — IAM Roles for Service Accounts

```bash
# 1. Enable OIDC provider for your cluster (if not already done)
eksctl utils associate-iam-oidc-provider \
  --region ap-south-1 \
  --cluster vault-cluster \
  --approve

# 2. Create an IAM role with a trust policy for the service account
eksctl create iamserviceaccount \
  --name vault-api-sa \
  --namespace production \
  --cluster vault-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve \
  --region ap-south-1
# This creates an IAM role AND annotates the Kubernetes service account

# 3. In your Deployment, use this service account:
spec:
  serviceAccountName: vault-api-sa   # pods now have S3 read access via IAM role
```

---

## CloudWatch — Monitoring and Observability

CloudWatch is AWS's built-in monitoring service. It collects metrics, logs, and traces from all AWS services automatically.

### CloudWatch Concepts

**Metrics**: time-series data points. Every AWS service publishes metrics to CloudWatch automatically (EC2 CPU, RDS connections, S3 bucket size, etc.).

**Logs**: CloudWatch Logs stores log groups. EC2 instances use the CloudWatch Agent to ship logs; Lambda functions log here automatically.

**Alarms**: trigger SNS notifications, Auto Scaling actions, or EC2 actions when a metric breaches a threshold.

**Dashboards**: visual dashboards in the AWS console.

**Insights**: run SQL-like queries on CloudWatch Logs to find patterns.

### CloudWatch CLI Commands

```bash
# Get a metric (EC2 CPU utilization for the last hour)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average

# List available metrics for EC2
aws cloudwatch list-metrics --namespace AWS/EC2

# Create an alarm (alert when CPU > 80% for 5 minutes)
aws cloudwatch put-metric-alarm \
  --alarm-name "High CPU - vault-api" \
  --alarm-description "Alert when CPU exceeds 80%" \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:ap-south-1:123456789012:ops-alerts \
  --ok-actions arn:aws:sns:ap-south-1:123456789012:ops-alerts

# List alarms and their states
aws cloudwatch describe-alarms \
  --query "MetricAlarms[*].[AlarmName,StateValue,MetricName]" \
  --output table

# View log groups
aws logs describe-log-groups

# View log streams in a group
aws logs describe-log-streams \
  --log-group-name /aws/ec2/vault-api

# Get log events
aws logs get-log-events \
  --log-group-name /aws/ec2/vault-api \
  --log-stream-name vault-api-i-1234567890abcdef0 \
  --limit 100

# CloudWatch Insights query (find errors in the last hour)
aws logs start-query \
  --log-group-name /aws/ec2/vault-api \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100'
# Then retrieve results with:
aws logs get-query-results --query-id <query-id-from-above>
```

---

## Common Misunderstanding: "CloudWatch is enough for K8s monitoring"

**The misunderstanding:** "I'm on EKS — I'll just use CloudWatch Container Insights for all my monitoring."

**The reality:** CloudWatch Container Insights gives you basic Kubernetes metrics (pod CPU, memory, node metrics). But:
- The query language is SQL-like Insights, not PromQL — much less powerful for time-series analysis
- No histogram metrics (can't calculate P95 latency)
- Limited customization and dashboard flexibility vs Grafana
- App-level metrics (business metrics, custom counters) require you to push them explicitly
- Costs can be high at large log volumes in CloudWatch Logs vs Loki

The real production pattern at most companies:
- **Infrastructure metrics**: CloudWatch (it's automatic, built-in for AWS services)
- **Application metrics**: Prometheus + Grafana
- **Application logs**: Loki (much cheaper than CloudWatch Logs at scale)
- **AWS service events/audit logs**: CloudWatch Logs (CloudTrail → CloudWatch)

Both systems complement each other — CloudWatch for AWS-native visibility, Prometheus/Loki for your application observability.

→ Continue to: `README.md`
