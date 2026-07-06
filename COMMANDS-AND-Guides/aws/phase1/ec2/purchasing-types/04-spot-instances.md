# EC2 Purchasing — 04: Spot Instances

> **Last updated:** July 6, 2026
> **The deepest discount in AWS (70–90% off). The catch: AWS can take them back. Here's everything.**

---

## The Core Idea

AWS has massive amounts of spare compute capacity — servers that are paid for but not being used by On-Demand or Reserved customers. Rather than leave them idle, AWS sells this spare capacity at heavily discounted prices. These are **Spot Instances**.

```
AWS's spare capacity pool → Spot market → Your Spot instance

AWS can reclaim this capacity anytime with 2 minutes warning.
In exchange for accepting this risk, you get 70–90% off.
```

---

## How Spot Pricing Works

### Spot Price

The **Spot price** is the current hourly rate for a Spot instance. It fluctuates based on supply and demand for spare capacity in each **capacity pool**.

A **capacity pool** = one instance type in one AZ in one region.

```
ap-south-1a + m5.large = one pool
ap-south-1b + m5.large = different pool
ap-south-1a + c5.large = different pool
```

Each pool has its own price history.

### Price History Example

```
m5.large in ap-south-1a (On-Demand price: $0.096/hr):

Date          Spot Price
2026-07-01    $0.014/hr  (85% discount)
2026-07-02    $0.015/hr
2026-07-03    $0.016/hr
2026-07-04    $0.014/hr
2026-07-05    $0.028/hr  (price spiked — demand increased)
2026-07-06    $0.015/hr
```

Spot prices are generally stable for hours or days. The big spikes are rare but possible.

```bash
# Check current spot price
aws ec2 describe-spot-price-history \
  --instance-types m5.large \
  --product-descriptions "Linux/UNIX" \
  --availability-zone ap-south-1a \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --query 'SpotPriceHistory[*].{AZ:AvailabilityZone,Price:SpotPrice,Time:Timestamp}'
```

### Your "Max Price"

When you request a Spot instance, you can optionally set a **max price** — the maximum you're willing to pay per hour. If the Spot price rises above your max price, your instance is interrupted.

**However, AWS recommends NOT setting a max price.** Why? The default max price is the On-Demand price. So you'll never pay more than On-Demand — and you can take advantage of any price below that.

```
Spot price: $0.015/hr
Your max: (not set — defaults to On-Demand $0.096/hr)
Result: You pay $0.015/hr. If price ever exceeds $0.096/hr → instance interrupted.

But a price spike to $0.097/hr (above On-Demand) is extremely rare.
The interruptions you need to worry about are NOT price-based — they're capacity-based.
```

---

## Interruptions — The Real Risk

**Most Spot interruptions are NOT due to price spikes.** They happen because AWS needs the capacity back for On-Demand customers.

```
Example:
  You're running a Spot m5.large in ap-south-1a
  A large company launches 1,000 On-Demand m5.large instances in ap-south-1a
  AWS needs that capacity → your Spot instance is reclaimed
```

### The 2-Minute Warning

Before interrupting your instance, AWS:
1. Changes the instance state to `shutting-down` (visible in metadata)
2. Sends a **Spot interruption notice** via the instance metadata service
3. Gives you 2 minutes to save state, drain connections, etc.

**How to detect the 2-minute warning from inside your instance:**

```bash
# Poll this URL every 5 seconds from inside the EC2 instance
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/spot/interruption-action
# Returns nothing if no interruption coming
# Returns "terminate" or "hibernate" or "stop" if interruption is imminent
```

**CloudWatch + EventBridge approach (better):**

```bash
# AWS emits an event 2 minutes before interruption
# Listen for it in EventBridge:
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Spot Instance Interruption Warning"]
}
```

Typical response to an interruption warning:
1. Stop accepting new work
2. Save current work state to S3 or SQS
3. Deregister from the load balancer (if applicable)
4. Log the interruption
5. Instance terminates → ASG or Spot Fleet launches a replacement

---

## Spot Instance Request Types

### One-Time Request

```
You request 1 Spot instance.
Instance is launched when capacity is available.
When interrupted → instance terminates, request is DONE. No replacement.
```

### Persistent Request

```
You request 1 Spot instance, persistently.
Instance is launched when capacity is available.
When interrupted → instance terminates, request STAYS OPEN.
When capacity is available again → new instance is launched automatically.
```

```bash
# Create a persistent Spot request
aws ec2 request-spot-instances \
  --spot-price "0.050" \
  --instance-count 1 \
  --type persistent \               ← persistent, not one-time
  --launch-specification '{
    "ImageId": "ami-xxxx",
    "InstanceType": "m5.large",
    "SecurityGroupIds": ["sg-xxxx"],
    "SubnetId": "subnet-xxxx"
  }'

# Cancel a persistent spot request (does NOT terminate the instance)
aws ec2 cancel-spot-instance-requests --spot-instance-request-ids sir-xxxx

# Terminate the instance separately
aws ec2 terminate-instances --instance-ids i-xxxx
```

**Note:** Always cancel the Spot request before terminating the instance.
If you only terminate the instance, the persistent request will launch a new one!

---

## Spot Fleet

A **Spot Fleet** is a collection of Spot instances (and optionally On-Demand instances) that AWS manages for you. It automatically maintains your target capacity by launching instances across multiple pools.

```
You say:  "I need 10 vCPUs of capacity, cheaply"
Fleet says: "I'll spread across m5.large (AZ-a), c5.large (AZ-a), m5.large (AZ-b)
             so that if one pool is interrupted, others still run"
```

### Fleet Allocation Strategies

This is the most important Spot Fleet concept. The strategy determines which pools AWS picks instances from.

#### `lowest-price` Strategy

```
AWS picks instances from the cheapest pool(s).

Behavior:
  → Maximizes cost savings
  → BUT: concentrates capacity in one pool
  → If that pool gets interrupted → most/all of your fleet is interrupted simultaneously
  → High interruption risk

Use case: Short batch jobs where you care more about cost than availability
```

#### `diversified` Strategy

```
AWS spreads instances across ALL specified pools (roughly equal distribution).

Behavior:
  → If 1 pool is interrupted → only a fraction of your fleet is affected
  → Others keep running while replacements are found
  → Slightly higher average cost (you're not always in the cheapest pool)

Use case: Any workload needing sustained capacity (data processing, ML training)
          Recommended for most production Spot use cases
```

#### `capacity-optimized` Strategy (Recommended for most cases)

```
AWS launches instances from the pools with the MOST available spare capacity.

Behavior:
  → More available capacity = lower probability of interruption
  → AWS knows which pools have the most spare capacity
  → You get lower interruption rates, not necessarily lowest price
  → Usually within ~5-10% of lowest-price in practice

Use case: When you want the best availability of Spot capacity
```

#### `price-capacity-optimized` Strategy (Newest — use this one)

```
Balances the lowest price with the most capacity.
AWS-recommended default strategy.

Best of both worlds:
  → Selects pools with the best balance of low price + high capacity
  → Generally lowest interruption rates
  → Near-optimal pricing
```

---

## EC2 Auto Scaling with Spot — Mixed Instances Policy

In production, you don't use Spot Fleet directly — you use it through an **Auto Scaling Group** with a **Mixed Instances Policy**.

This lets you define:
- A base of On-Demand instances (reliable, never interrupted)
- A Spot portion for the bulk of the fleet (cheap, may be interrupted)
- Multiple instance types (so if one pool is interrupted, ASG uses a different type)

```json
{
  "MixedInstancesPolicy": {
    "InstancesDistribution": {
      "OnDemandBaseCapacity": 2,         ← always keep at least 2 On-Demand (base)
      "OnDemandPercentageAboveBaseCapacity": 0,  ← scale the rest with Spot
      "SpotAllocationStrategy": "price-capacity-optimized"
    },
    "LaunchTemplate": {
      "LaunchTemplateSpecification": {
        "LaunchTemplateName": "my-template",
        "Version": "$Latest"
      },
      "Overrides": [
        { "InstanceType": "m5.large" },   ← pool 1
        { "InstanceType": "m5a.large" },  ← pool 2 (similar CPU/RAM, different CPU vendor)
        { "InstanceType": "m4.large" },   ← pool 3
        { "InstanceType": "c5.large" },   ← pool 4 (different family, similar cost)
        { "InstanceType": "c5a.large" }   ← pool 5
      ]
    }
  }
}
```

```
Min capacity: 2 (On-Demand)
Desired: 10 (2 On-Demand + 8 Spot)
Max: 20 (2 On-Demand + 18 Spot)

If Spot pool 1 (m5.large, AZ-a) is interrupted:
  → ASG automatically replaces with another pool (m5a.large, m4.large, or different AZ)
  → During replacement, traffic continues to the 7 remaining + 2 On-Demand
```

---

## Spot Instance Hibernation

Instead of terminating on interruption, a Spot instance can **hibernate** — saving RAM contents to EBS and restoring them when capacity is available again.

```
Normal interruption: Instance terminates → state is LOST → restart from scratch
Hibernation:         RAM → saved to EBS → instance "sleeps" → wakes up with full state restored
```

**Requirements:**
- Instance must be configured with hibernation enabled at launch
- RAM must fit on the root EBS volume (root volume ≥ RAM size)
- Linux only (Amazon Linux 2, Ubuntu 18.04+)
- Root volume must be encrypted
- Not all instance types support hibernation

```bash
# Launch a Spot instance with hibernation enabled
aws ec2 run-instances \
  --instance-type m5.large \
  --image-id ami-xxxx \
  --hibernation-options Configured=true \
  --instance-market-options '{
    "MarketType": "spot",
    "SpotOptions": {
      "InstanceInterruptionBehavior": "hibernate"
    }
  }' \
  --block-device-mappings '[{
    "DeviceName": "/dev/xvda",
    "Ebs": {
      "VolumeSize": 20,
      "Encrypted": true
    }
  }]'
```

**Use case:** Long-running jobs that can't easily checkpoint (ML training, simulations). Instead of saving state manually, hibernation does it automatically.

---

## Stop vs Hibernate vs Terminate on Interruption

| Behavior | What Happens | When to Use |
|----------|-------------|------------|
| **Terminate** (default) | Instance is deleted, storage lost (unless separate EBS) | Stateless workloads, batch jobs |
| **Stop** | Instance stopped (EBS data preserved, RAM lost) | Stateful apps that can resume from disk |
| **Hibernate** | RAM saved to EBS, instance restarts with same state | Long computations that are too expensive to restart |

---

## EC2 Spot Advisor

AWS provides the **Spot Instance Advisor** tool at aws.amazon.com/ec2/spot/instance-advisor/

It shows:
```
For each instance type + region:
  → Interruption frequency: <5%, 5-10%, 10-15%, 15-20%, >20%
  → Savings vs On-Demand

Use this to pick instance types with LOW interruption rates.
m5.large might have 15% interruption rate in ap-south-1a
m5a.large might have <5% in the same region
→ Run m5a.large for more stability at similar price
```

---

## Spot Best Practices

### 1. Always specify multiple instance types

```
Don't: Request only m5.large Spot
Do:    Request [m5.large, m5a.large, m4.large, c5.large, c5a.large]

More types = more pools = lower chance ALL pools are interrupted simultaneously
```

### 2. Spread across multiple AZs

```
Don't: Only ap-south-1a
Do:    ap-south-1a + ap-south-1b + ap-south-1c

Interruption events are usually AZ-specific, not region-wide
```

### 3. Use capacity-optimized or price-capacity-optimized strategy

```
Don't: lowest-price (concentrates in one pool)
Do:    price-capacity-optimized (best balance of price + availability)
```

### 4. Design for interruption

```
Build your app assuming any instance can die at any moment:
  → Store state in S3, DynamoDB, or SQS (not local disk)
  → Use job queues (SQS) — interrupted job returns to queue
  → Configure graceful shutdown (handle SIGTERM signal)
  → Build checkpointing into long-running computations
```

### 5. Keep On-Demand for the minimum viable fleet

```
Always maintain some On-Demand instances as your "base":
  → 2 On-Demand out of 10 total = service never goes fully down
  → Spot saves money on the bulk 8 instances
  → On-Demand ensures continuity during mass Spot interruption
```

---

## Use Cases Where Spot Works Perfectly

```
✅ Big data processing (Spark/Hadoop on EMR)
     → Jobs can be retried if interrupted
     → Save 70% on processing costs

✅ CI/CD build agents
     → Each build is independent and re-runnable
     → GitHub Actions self-hosted runners on Spot

✅ ML model training
     → Use checkpointing to save progress every N minutes
     → Resume from last checkpoint after interruption

✅ Image/video processing at scale
     → Processing pipeline: upload → queue → Spot workers → output
     → Interrupted worker → job returns to queue → another worker picks it up

✅ Web crawlers and scrapers
     → Each URL is independent, easily retried

✅ Load testing
     → Generate millions of requests cheaply
     → If an instance dies mid-test, that's fine
```

---

## What NOT to Run on Spot

```
❌ Production databases (cannot afford to lose data or downtime)
❌ Single-instance web servers with no replication
❌ Any workload with strict SLA requirements
❌ Anything that takes >1 hour to restart from scratch (and has no checkpointing)
❌ Kubernetes control plane nodes (worker nodes: yes, control plane: no)
```

---

## Cost Example: Spark Job on EMR

```
Job: Process 10TB of logs, takes ~4 hours on 20× m5.xlarge

On-Demand:
  20 × m5.xlarge × 4hr = 20 × $0.192 × 4 = $15.36

Spot (at ~80% discount, assuming some interruptions add 20% more time):
  20 × m5.xlarge × ~4.8hr = 20 × $0.038 × 4.8 = $3.65

Savings: $11.71 (76% cheaper)
```

For batch jobs run hundreds of times a month, this adds up to thousands of dollars saved.

→ Continue to: `05-dedicated.md`
