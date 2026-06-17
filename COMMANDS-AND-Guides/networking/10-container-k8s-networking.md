# Networking — Part 10: Container and Kubernetes Networking

**20-minute read. Containers and Kubernetes add layers of virtual networking. Understand these or debugging becomes guessing.**

---

## Docker Networking — The Four Modes

### Bridge (Default)

Containers get a private IP on a virtual bridge network (`172.17.0.0/16`). Docker creates `docker0` bridge interface on the host. The host NATs container traffic to the outside world.

```bash
# Default bridge: containers get 172.17.x.x IPs
docker run -d nginx
docker inspect -f '{{.NetworkSettings.IPAddress}}' $(docker ps -lq)
# 172.17.0.2

# Problem with default bridge: containers can't reach each other by name
# Solution: create a CUSTOM bridge network
docker network create app-network

docker run -d --name postgres --network app-network postgres:15
docker run -d --name api --network app-network vault-app:v1.0

# Now api can reach postgres by NAME (Docker provides DNS on custom networks)
docker exec api curl http://postgres:5432
docker exec api ping postgres    # resolves to postgres container's IP
```

### Host Network

```bash
# Container shares the host's network stack — no NAT, no bridge
docker run -d --network host nginx
# nginx listens on port 80 of the HOST directly
# No -p flag needed — container's ports ARE the host's ports
# Performance: slightly better (no NAT overhead)
# Security: container can access all host network interfaces
```

### None

```bash
# Completely isolated — no network interfaces except loopback
docker run -d --network none vault-app:v1.0
# Use for: batch jobs, security-sensitive containers that need no network
```

### Overlay (Docker Swarm — Multi-Host)

```bash
# Overlay networks span multiple Docker hosts (Docker Swarm)
docker network create --driver overlay --attachable swarm-network
# Containers on different hosts can communicate as if on same network
# Each host has a VXLAN interface that encapsulates traffic
```

---

## Docker Networking Commands

```bash
# List all networks
docker network ls
# NETWORK ID   NAME         DRIVER    SCOPE
# abc123       bridge       bridge    local      ← default
# def456       host         host      local
# ghi789       none         null      local
# jkl012       app-network  bridge    local      ← custom

# Create a network
docker network create app-network
docker network create --subnet 192.168.100.0/24 --gateway 192.168.100.1 custom-net

# Inspect a network (see IPs, connected containers)
docker network inspect app-network

# Connect a running container to a network
docker network connect app-network existing-container

# Disconnect
docker network disconnect app-network existing-container

# Delete a network (must be unused)
docker network rm app-network
docker network prune    # remove all unused networks
```

### Debug Docker Networking

```bash
# See a container's IP and network info
docker inspect --format '{{json .NetworkSettings.Networks}}' vault-api | jq

# See all IPs for all running containers
docker inspect -f '{{.Name}} → {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  $(docker ps -q)

# Trace traffic between containers
# On the host, watch the docker bridge:
sudo tcpdump -i docker0 -nn -A

# Enter container network namespace for debugging
PID=$(docker inspect --format '{{.State.Pid}}' vault-api)
sudo nsenter -t $PID -n ss -tlnp    # see ports inside container
sudo nsenter -t $PID -n ip route    # see container's routing table
```

---

## Kubernetes Networking Model

The Kubernetes networking model has three rules:
1. Every pod gets its own IP address
2. All pods can reach all other pods WITHOUT NAT
3. All nodes can reach all pods without NAT

No matter which node they're on, pods can talk to each other directly by IP.

### The Kubernetes Network Architecture

```
Node 1 (10.0.1.10)
  Pod A (10.244.0.5)  ──┐
  Pod B (10.244.0.6)  ──┤── cni0 bridge ── flannel.1 VXLAN ──┐
                                                               │
Node 2 (10.0.1.11)                                            │ (tunnel)
  Pod C (10.244.1.5)  ──┐                                     │
  Pod D (10.244.1.6)  ──┤── cni0 bridge ── flannel.1 VXLAN ──┘
```

- Each node has a `cni0` bridge (or `cbr0` depending on CNI plugin)
- Pods connect to the bridge via `veth` pairs (virtual Ethernet — one end in pod, one end on host)
- The CNI plugin (Flannel, Calico, Cilium) creates tunnels between nodes (VXLAN or direct routing)

### How Packets Travel Between Pods on Different Nodes

```
Pod A (10.244.0.5) on Node 1 sends to Pod C (10.244.1.5) on Node 2:

1. Pod A → default route → cni0 bridge (10.244.0.1)
2. Node 1 routing table: 10.244.1.0/24 via Node 2 (or via VXLAN)
3. Flannel encapsulates packet in UDP (VXLAN) → sends to Node 2 port 8472
4. Node 2 receives → decapsulates → delivers to Pod C via its cni0 bridge
```

---

## Debugging Kubernetes Network

```bash
# See all pod IPs
kubectl get pods -n production -o wide
# NAME                  READY STATUS    IP            NODE
# vault-api-7d4b9c-xyz  1/1   Running   10.244.1.15   worker-node-2

# Can pod A reach pod B?
kubectl exec -it pod-a -n production -- curl http://10.244.1.15:3000/health

# Can pod reach external internet?
kubectl exec -it vault-api -n production -- curl -s https://ifconfig.me

# Check what interfaces exist inside a pod
kubectl exec -it vault-api -n production -- ip addr show
# eth0: inet 10.244.1.15/24   ← pod's main interface
# lo:   inet 127.0.0.1/8

# Check pod's routing table
kubectl exec -it vault-api -n production -- ip route
# default via 10.244.1.1 dev eth0    ← default: go to CNI gateway
# 10.244.1.0/24 dev eth0             ← same subnet: direct

# Check pod's DNS config
kubectl exec -it vault-api -n production -- cat /etc/resolv.conf

# Check which node a pod is on
kubectl get pod vault-api-7d4b9c-xyz -n production -o jsonpath='{.spec.nodeName}'
```

### Check CNI Plugin Health

```bash
# Flannel
kubectl get pods -n kube-flannel
kubectl logs -n kube-flannel daemonset/kube-flannel-ds

# Calico
kubectl get pods -n kube-system | grep calico
kubectl logs -n kube-system daemonset/calico-node
kubectl exec -it -n kube-system calico-node-xxxxx -- calicoctl node status

# Cilium
kubectl -n kube-system exec ds/cilium -- cilium status
kubectl -n kube-system exec ds/cilium -- cilium endpoint list
```

---

## Kubernetes Service Networking — How ClusterIP Works

```bash
# Create a service
kubectl get service vault-api-service -n production
# NAME                TYPE        CLUSTER-IP    EXTERNAL-IP  PORT(S)
# vault-api-service   ClusterIP   10.96.45.23   <none>       80/TCP

# How kube-proxy implements this on each node:
# (iptables mode):
sudo iptables -t nat -L KUBE-SERVICES -n | grep 10.96.45.23
# KUBE-SVC-XXXXX tcp -- 0.0.0.0/0 10.96.45.23 tcp dpt:80

sudo iptables -t nat -L KUBE-SVC-XXXXX -n
# KUBE-SEP-AAA  -- probabilistic 0.33
# KUBE-SEP-BBB  -- probabilistic 0.50
# KUBE-SEP-CCC  -- always
# 3 endpoints → 33%/50%/100% probability = equal distribution

# Each KUBE-SEP rule does DNAT to a pod IP:
sudo iptables -t nat -L KUBE-SEP-AAA -n
# DNAT tcp -- 0.0.0.0/0 0.0.0.0/0 to:10.244.1.15:3000
```

### Debugging Service Connectivity

```bash
# 1. Does the service exist?
kubectl get service vault-api-service -n production

# 2. Does the service have endpoints?
kubectl get endpoints vault-api-service -n production
# NAME                ENDPOINTS                         AGE
# vault-api-service   10.244.1.15:3000,10.244.1.16:3000  2h
# If ENDPOINTS is <none> → no pods match the service selector → check pod labels

# 3. Do the pod labels match the service selector?
kubectl get service vault-api-service -n production -o yaml | grep -A 5 selector
# selector:
#   app: vault-api
kubectl get pods -n production -l app=vault-api
# If no pods → label mismatch

# 4. Test from within the cluster
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://vault-api-service.production/health

# 5. Test with ClusterIP directly
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://10.96.45.23/health
```

---

## NetworkPolicy — Kubernetes Firewall

NetworkPolicy acts as a firewall between pods. By default, all pods can reach all other pods. Adding a NetworkPolicy restricts this.

```bash
# See existing NetworkPolicies
kubectl get networkpolicy -n production

# Describe a policy
kubectl describe networkpolicy vault-api-policy -n production
```

```yaml
# Allow vault-api to only receive traffic from vault-frontend pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vault-api-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: vault-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: vault-frontend
      ports:
        - port: 3000
```

```bash
# After applying: test connectivity
kubectl exec -it vault-frontend-pod -- curl http://vault-api-service:3000/health   # should work
kubectl exec -it other-pod -- curl http://vault-api-service:3000/health             # should be blocked
```

---

## Ingress Networking — External Traffic Flow

```
Internet → Cloud Load Balancer → Ingress Controller Pod (nginx) → Service → Pods
```

```bash
# Check Ingress Controller is running
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx
# NAME                      TYPE          CLUSTER-IP    EXTERNAL-IP
# ingress-nginx-controller  LoadBalancer  10.96.123.45  34.100.200.50  ← public IP

# Check your Ingress
kubectl get ingress -n production
# NAME           CLASS   HOSTS             ADDRESS        PORTS
# vault-ingress  nginx   vault.example.com 34.100.200.50  80, 443

# Describe for detailed config and events
kubectl describe ingress vault-ingress -n production

# Test Ingress routing manually (override DNS)
curl -H "Host: vault.example.com" http://34.100.200.50/health

# Ingress Controller logs (see which requests are routed where)
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50 -f
```

---

## Common Misunderstanding: "Kubernetes Pods Can't Reach the Internet"

**The misunderstanding:** "Pods are in an internal network — they can't reach external services."

**The reality:** By default, pods CAN reach the internet via NAT. The node's IP tables masquerade pod traffic — packets from `10.244.1.15` leave the node with the node's IP. Return traffic is un-NATed back to the pod.

```bash
# Test from a pod
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- https://ifconfig.me
# Returns the NODE's public IP — proves internet access works
```

Pods cannot reach the internet ONLY when:
1. The cluster is in a private VPC with no NAT Gateway
2. A NetworkPolicy blocks egress
3. The CNI plugin doesn't set up masquerade rules

If you need to block internet access from pods, you need explicit NetworkPolicy egress rules — it's not blocked by default.

→ Continue to: `11-real-world-troubleshooting.md`
