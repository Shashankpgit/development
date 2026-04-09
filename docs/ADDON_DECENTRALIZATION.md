# Addon Decentralization — Discussion Forum

> **Scope:** This document describes the complete decentralization of the Discussion Forum addon
> (NodeBB + discussionmw + groups-service) from the core Sunbird installer.
>
> **Date:** 2026-02-19
> **Status:** Complete (OpenTofu infra scripts excluded — tracked separately)

---

## Background

Previously, the Discussion Forum addon was tightly coupled into the core installer:

- Nginx public/private ingress configs contained hardcoded `location /discussions/` and `location /nodebb/` blocks.
- Kong consumer group lists (`mobile_device`, `api_admin`, etc.) contained addon-specific ACL groups (`discussionAccess`, `groupCreate`, …).
- The `kong-consumers.py` script performed a **full sync** of ACL groups — any group not in the core input file was deleted, making it impossible for an addon to independently manage groups.
- Helm charts for `nodebb`, `discussionmw`, and `groups` lived inside the core `helmcharts/` directory.
- Docker image references, resource quota definitions, and service URLs were all scattered through core config files.

The goal was to allow the Discussion Forum addon to be **installed and uninstalled independently**, without any manual edits to core charts.

---

## Architecture: Before vs After

### Before

```
helmcharts/
├── edbb/charts/nodebb/          ← core
├── edbb/charts/discussionmw/    ← core
├── learnbb/charts/groups/       ← core
├── kong-consumers/values.yaml   ← contained discussionAccess, groupCreate, …
├── global-resources.yaml        ← nodebb, discussionmw, groups resource blocks
├── images.yaml                  ← nodebb, discussion_mw, groups image anchors
└── nginx-public-ingress/
    └── configs/proxy-default.conf   ← /discussions/ and /discussion-ui/ location blocks hardcoded
    └── nginx-private-ingress/configs/nginx.conf ← /nodebb/ location block hardcoded
```

### After

```
addons/discussion-forum/
├── helmcharts/
│   ├── nodebb/                          ← addon-owned chart
│   │   └── templates/
│   │       ├── nginx-configmap.yaml     ← public nginx location blocks (NEW)
│   │       └── nginx-private-configmap.yaml ← private nginx location blocks (NEW)
│   ├── discussionmw/                    ← addon-owned chart
│   ├── groups/                          ← addon-owned chart
│   ├── discussion-forum-apis/           ← Kong API routes for the addon (NEW)
│   └── discussion-forum-consumers/      ← ACL group injection for core consumers (NEW)
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── configs/kong-consumers.yaml
│       └── templates/job.yaml
└── scripts/
    └── addon.sh                        ← orchestrates install/uninstall of all above

helmcharts/ (core — no more addon references)
├── nginx-public-ingress/configs/proxy-default.conf  ← include hook only
├── nginx-public-ingress/templates/deployment.yaml   ← addon-config volume
├── nginx-private-ingress/configs/nginx.conf         ← include hook only
├── nginx-private-ingress/templates/deployment.yaml  ← addon-config volume
└── kong-consumers/values.yaml                       ← no discussion/group groups
```

---

## Changes Made

### 1. Nginx Public Ingress — Location Block Injection

**Problem:** `proxy-default.conf` had hardcoded `location /discussions/` and `location ~* ^/discussion-ui/` blocks.

**Solution:**
- Removed both blocks from the core config.
- Added an `include` directive at the end of the `server {}` block:
  ```nginx
  # Addon location blocks are injected here when an addon is installed.
  include /etc/nginx/conf.d/addons/*.conf;
  ```

**How the include injection works — step by step:**

```
1. Addon is deployed
   └─ Helm creates ConfigMap "discussion-forum-nginx-config"
      └─ data:
           nodebb.conf: |
             location /discussions/ { ... }

2. Core nginx-public-ingress Deployment has a projected volume:
   └─ sources:
        - configMap:
            name: discussion-forum-nginx-config
            optional: true         ← nginx starts fine even when absent
   └─ mountPath: /etc/nginx/conf.d/addons/

3. Inside the nginx container the filesystem looks like:
   /etc/nginx/conf.d/addons/nodebb.conf   ← ConfigMap key "nodebb.conf" = file

4. proxy-default.conf ends with:
   include /etc/nginx/conf.d/addons/*.conf;
   └─ nginx loads nodebb.conf → location /discussions/ is now active

5. Addon is uninstalled
   └─ ConfigMap deleted
   └─ Reloader (stakater/reloader) detects ConfigMap change, restarts nginx pod
   └─ /etc/nginx/conf.d/addons/ is empty
   └─ include *.conf matches nothing → nginx starts without the route
```

**Toggle — public vs private ingress:**

In `nodebb/values.yaml`, two flags control which ConfigMaps are created:

```yaml
nginx:
  publicIngress:
    enabled: true   # creates discussion-forum-nginx-config
                    # → injects /discussions/ and /discussion-ui/ into nginx-public-ingress
  privateIngress:
    enabled: true   # creates discussion-forum-private-nginx-config
                    # → injects /nodebb/ into nginx-private-ingress
```

Usage examples:
```bash
# Only public ingress (no internal /nodebb/ route needed)
helm upgrade nodebb . --set nginx.privateIngress.enabled=false

# Only private ingress (fronted by your own external ingress)
helm upgrade nodebb . --set nginx.publicIngress.enabled=false

# Both (default)
helm upgrade nodebb .
```

- Added a **projected volume** to `nginx-public-ingress/templates/deployment.yaml` that mounts an optional ConfigMap named `discussion-forum-nginx-config`:
  ```yaml
  - name: addon-config
    projected:
      sources:
      - configMap:
          name: discussion-forum-nginx-config
          optional: true  # core nginx starts even without the addon
  ```
- Created `addons/discussion-forum/helmcharts/nodebb/templates/nginx-configmap.yaml` containing the location blocks. When the addon is deployed, this ConfigMap is created and Nginx automatically picks it up via the `include` directive.

**Files changed:**
| File | Change |
|------|--------|
| `helmcharts/edbb/charts/nginx-public-ingress/configs/proxy-default.conf` | Removed discussion blocks; added `include` |
| `helmcharts/edbb/charts/nginx-public-ingress/templates/deployment.yaml` | Added `addon-config` volume + mount |
| `addons/discussion-forum/helmcharts/nodebb/templates/nginx-configmap.yaml` | **Created** — public nginx ConfigMap |

---

### 2. Nginx Private Ingress — Location Block Injection

**Problem:** `nginx-private-ingress/configs/nginx.conf` had a hardcoded `location /nodebb/` block for internal routing.

**Solution:** Same pattern as public ingress:
- Removed the `/nodebb/` location block from core.
- Added `include /etc/nginx/conf.d/addons/*.conf;` inside the `server {}` block.
- Added `addon-config` projected volume to `deployment.yaml` (references optional ConfigMap `discussion-forum-private-nginx-config`).
- Created `addons/discussion-forum/helmcharts/nodebb/templates/nginx-private-configmap.yaml` with the `/nodebb/` proxy block.

**Files changed:**
| File | Change |
|------|--------|
| `helmcharts/edbb/charts/nginx-private-ingress/configs/nginx.conf` | Removed `/nodebb/` block; added `include` |
| `helmcharts/edbb/charts/nginx-private-ingress/templates/deployment.yaml` | Added `addon-config` volume + mount |
| `addons/discussion-forum/helmcharts/nodebb/templates/nginx-private-configmap.yaml` | **Created** — private nginx ConfigMap |

---

### 3. Kong Consumer ACL Group Management — Scoped Sync (`--managed-by`)

**Problem:** `kong_consumers.py` performed a **full sync** of ACL groups. It deleted any group on a consumer that wasn't in the current input file. This made it impossible for an addon to independently add groups (e.g. `discussionAccess`) to core consumers — the next core deploy would delete them.

**Solution: `--managed-by` scoped group sync**

`kong_consumers.py` was updated with the following logic:

```
owned_groups = union of ALL groups listed across ALL consumers in the input file

For each consumer:
  ADD groups in input that are not yet in Kong           (always safe)
  DELETE groups that are:
    (a) no longer in input, AND
    (b) in owned_groups                                  (this chart declared them)

  Groups not in owned_groups → untouched (owned by another chart)
```

A new CLI argument was added:
```bash
python kong_consumers.py consumers.json \
    --kong-admin-api-url http://kong:8001 \
    --managed-by discussion-forum   # or "core"
```

**Example lifecycle:**

| Event | owned_groups (core) | owned_groups (addon) | Result |
|-------|--------------------|--------------------|--------|
| Core deploy | `{contentAccess, userAccess, …}` | — | `discussionAccess` on consumer is untouched (not in core's owned set) |
| Addon install | — | `{discussionAccess, groupAccess, …}` | Groups added to consumers |
| Addon uninstall | — | `{discussionAccess, groupAccess, …}` | Groups removed from consumers |
| Core re-deploy after addon install | `{contentAccess, userAccess, …}` | — | Addon groups survive |

**Files changed:**
| File | Change |
|------|--------|
| `scripts/kong-api-scripts/kong_consumers.py` | Added `_derive_owned_groups()`, updated `_save_groups_for_consumer()` with scoped deletion, added `--managed-by` CLI arg |
| `helmcharts/edbb/charts/kong-consumers/templates/job.yaml` | Passes `--managed-by={{ .Values.managed_by }}` |
| `helmcharts/edbb/charts/kong-consumers/values.yaml` | Added `managed_by: core` |

---

### 4. Core Kong Consumers — Removed Addon ACL Groups

With scoped group management in place, the following ACL groups were removed from the core `kong-consumers/values.yaml` consumer group lists:

| Groups Removed | From Consumer Group Lists |
|----------------|---------------------------|
| `discussionAccess`, `discussionCreate` | `mobile_device_groups`, `kong_admin_groups`, `portal_loggedin` groups |
| `groupCreate`, `groupUpdate`, `groupAccess`, `groupAdmin` | `mobile_device_groups`, `desktop_device_groups`, `kong_all_consumer_groups`, `kong_admin_groups` |

These are now **owned and managed** by the `discussion-forum-consumers` addon chart.

**File changed:** `helmcharts/edbb/charts/kong-consumers/values.yaml`

---

### 5. New: `discussion-forum-consumers` Helm Chart

**Created:** `addons/discussion-forum/helmcharts/discussion-forum-consumers/`

This chart runs a Kubernetes Job (post-install/post-upgrade hook) that calls `kong_consumers.py` with `--managed-by=discussion-forum`. It injects the following ACL groups into core consumers:

| Consumer | Groups Granted |
|----------|----------------|
| `mobile_device` | `discussionAccess`, `groupAccess`, `groupCreate`, `groupUpdate` |
| `mobile_devicev2` | `discussionAccess`, `groupAccess`, `groupCreate`, `groupUpdate` |
| `desktop_device` | `groupAccess`, `groupCreate`, `groupUpdate`, `groupAdmin` |
| `portal_loggedin` | `discussionAccess`, `discussionCreate`, `groupAccess`, `groupCreate`, `groupUpdate`, `groupAdmin` |
| `portal_loggedin_fallback_token` | same as above |
| `api_admin` | `discussionAccess`, `discussionCreate`, `groupAccess`, `groupAdmin`, `groupCreate`, `groupUpdate` |

**Key:** Only the groups declared here will ever be deleted by this chart. Core groups (`contentAccess`, `userAccess`, etc.) are never touched.

---

### 6. Removed Core Helm Charts

The following Helm charts were deleted from the core installer and are now fully managed by the addon:

| Chart Removed | Was Located At | Now Located At |
|---------------|----------------|----------------|
| `nodebb` | `helmcharts/edbb/charts/nodebb/` | `addons/discussion-forum/helmcharts/nodebb/` |
| `discussionmw` | `helmcharts/edbb/charts/discussionmw/` | `addons/discussion-forum/helmcharts/discussionmw/` |
| `groups` | `helmcharts/learnbb/charts/groups/` | `addons/discussion-forum/helmcharts/groups/` |

---

### 7. Removed Core Config References

| File | What Was Removed |
|------|-----------------|
| `helmcharts/global-resources.yaml` | Resource quota blocks for `nodebb`, `discussionmw`, `groups` |
| `helmcharts/images.yaml` | Image anchors `discussion_mw`, `nodebb`, `groups` and their `internal:` references |
| `helmcharts/edbb/charts/player/configs/env.yaml` | `discussions_middleware: "http://discussionmw-service:3002"` |
| `helmcharts/learnbb/charts/lms/values.yaml` | `sunbird_group_service_api_base_url: "http://groups-service:9000"` → now empty default |

---

### 8. Removed LMS Patching from Addon Script
**Decision:** The addon's `addon.sh` no longer attempts to patch the core LMS Helm release with the groups-service URL. This move ensures the addon has zero side-effects on the core installation.
- **Before:** Addon script would run `helm upgrade lms` to inject its own service URL into the core.
- **After:** Addon script is strictly limited to managing its own charts. Core LMS is configured independently in the main installer to point to the groups-service.

---

### 9. `addon.sh` — Updated Addon Orchestration

`addons/discussion-forum/script/addon.sh` now deploys all addon components in the correct order:

```
install order:
  1. discussion-forum-apis       ← register Kong API routes
  2. discussion-forum-consumers  ← inject ACL groups into core consumers
  3. discussionmw                ← start discussion middleware
  4. nodebb                      ← start NodeBB forum
  5. groups                      ← start groups service

uninstall order (reverse):
  1-5. uninstall all above
```

---

## What Deliberately Remains in Core

The following items were **intentionally left in core** and not decentralized:

| Item | File | Reason |
|------|------|--------|
| `nodebb_client_secret` | `learnbb/keycloak/values.yaml:128` | Keycloak registers the NodeBB OIDC client at boot time. This secret must exist in Keycloak config before NodeBB can authenticate users via SSO. Removing it breaks Keycloak OIDC setup. |
| Nginx `# nodebb.conf` comment | `nginx-public-ingress/templates/deployment.yaml` | A documentation comment only — no functional impact. |
| Monitoring health checks for groups/nodebb/discussionmw | `monitoring/charts/kube-prometheus-stack/values.yaml` | Monitoring is a separate concern; the checks simply fail silently when the addon is absent. Decoupling monitoring is tracked separately. |

---

## How to Add a New Addon

To add a new addon following this pattern:

### 1. Nginx routes

Add a ConfigMap in your addon chart:
```yaml
# addons/my-addon/helmcharts/my-service/templates/nginx-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-addon-nginx-config
data:
  my-addon.conf: |
    location /my-addon/ {
      proxy_pass http://my-service:8080/;
    }
```

Add the ConfigMap as a source in `nginx-public-ingress/templates/deployment.yaml`'s projected volume:
```yaml
- configMap:
    name: my-addon-nginx-config
    optional: true
```

### 2. Kong ACL groups

Create a `my-addon-consumers` chart with `values.yaml`:
```yaml
managed_by: my-addon
```

And a `configs/kong-consumers.yaml` listing only the groups your addon owns:
```yaml
kong_consumers:
  - username: mobile_device
    groups:
      - myAddonAccess
    state: present
    ...
```

Run the job with:
```bash
python kong_consumers.py consumers.json --managed-by=my-addon
```

Core will never delete `myAddonAccess` because it is not in core's `owned_groups`.

---

## File Index — All Changed Files

### New Files Created
| File | Purpose |
|------|---------|
| `addons/discussion-forum/helmcharts/nodebb/templates/nginx-configmap.yaml` | Public Nginx location blocks for the addon |
| `addons/discussion-forum/helmcharts/nodebb/templates/nginx-private-configmap.yaml` | Private Nginx `/nodebb/` proxy block |
| `addons/discussion-forum/helmcharts/discussion-forum-consumers/Chart.yaml` | Chart metadata |
| `addons/discussion-forum/helmcharts/discussion-forum-consumers/values.yaml` | Defaults including `managed_by: discussion-forum` |
| `addons/discussion-forum/helmcharts/discussion-forum-consumers/configs/kong-consumers.yaml` | Consumer group assignments owned by this addon |
| `addons/discussion-forum/helmcharts/discussion-forum-consumers/templates/job.yaml` | Kubernetes Job to run `kong_consumers.py` |

### Modified Files
| File | What Changed |
|------|-------------|
| `scripts/kong-api-scripts/kong_consumers.py` | Scoped `--managed-by` group sync |
| `helmcharts/edbb/charts/nginx-public-ingress/configs/proxy-default.conf` | Removed discussion blocks; added `include` |
| `helmcharts/edbb/charts/nginx-public-ingress/templates/deployment.yaml` | Added `addon-config` projected volume |
| `helmcharts/edbb/charts/nginx-private-ingress/configs/nginx.conf` | Removed `/nodebb/` block; added `include` |
| `helmcharts/edbb/charts/nginx-private-ingress/templates/deployment.yaml` | Added `addon-config` projected volume |
| `helmcharts/edbb/charts/kong-consumers/values.yaml` | Removed discussion/group ACL groups; added `managed_by: core` |
| `helmcharts/edbb/charts/kong-consumers/templates/job.yaml` | Passes `--managed-by` flag |
| `helmcharts/global-resources.yaml` | Removed nodebb, discussionmw, groups resource blocks |
| `helmcharts/images.yaml` | Removed discussion_mw, nodebb, groups image anchors |
| `helmcharts/edbb/charts/player/configs/env.yaml` | Removed `discussions_middleware` env var |
| `helmcharts/learnbb/charts/lms/values.yaml` | Cleared `sunbird_group_service_api_base_url` default |
| `addons/discussion-forum/script/addon.sh` | Added discussion-forum-apis, discussion-forum-consumers to deploy order |

### Deleted Files (Core Charts Removed)
| Deleted | Reason |
|---------|--------|
| `helmcharts/edbb/charts/nodebb/` | Moved to `addons/discussion-forum/helmcharts/nodebb/` |
| `helmcharts/edbb/charts/discussionmw/` | Moved to `addons/discussion-forum/helmcharts/discussionmw/` |
| `helmcharts/learnbb/charts/groups/` | Moved to `addons/discussion-forum/helmcharts/groups/` |
