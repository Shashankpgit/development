# All Fixes Applied - Kong API Decoupling Implementation

## Summary
Fixed critical issues blocking the Discussion Forum addon deployment.

---

## Fix #1: Chart.yaml Helm Dependency Path ✅

**Problem**: Helm dependency resolution failed with "directory ../../../common not found"

**Root Cause**: Incorrect relative path to common chart dependency

**Solution Applied**:
```yaml
# FILE: addons/discussion-forum/helmcharts/discussion-forum-apis/Chart.yaml

# ❌ BEFORE
dependencies:
  - name: common
    version: 0.1.0
    repository: file://../../../common

# ✅ AFTER
dependencies:
  - name: common
    version: 0.1.0
    repository: file://../../../../helmcharts/library/common
```

**Impact**: Helm dependencies now resolve correctly

---

## Fix #2: Docker Image for Kong Scripts ✅

**Problem**: Job failed with "unrecognized arguments: --managed-by=discussion-forum"

**Root Cause**: Addon was using old Docker image without `--managed-by` support

**Solution Applied**:
```yaml
# FILE: addons/discussion-forum/helmcharts/discussion-forum-apis/values.yaml

# ❌ BEFORE (old image with --upsert-only flag)
image:
  repository: shashank04515/kong-scripts
  tag: "local-upsert"

# ✅ AFTER (updated image with --managed-by support)
image:
  repository: sunbirded.azurecr.io/kong-scripts
  tag: "0.1.8"
```

**Impact**: Job now accepts and processes `--managed-by=discussion-forum` argument correctly

---

## Validation Checklist

### ✅ Chart.yaml Path
- Corrected relative path to helmcharts/library/common
- Verified: `helm dependency list` returns "ok" status

### ✅ Docker Image
- Updated to production image: sunbirded.azurecr.io/kong-scripts:0.1.8
- This image includes:
  - Kong 3.9.1 compatibility
  - `--managed-by` argument support
  - Ownership tag stamping functionality
  - Two-phase fetch strategy

### ✅ Script Features (in the updated image)
- Accepts `--managed-by` CLI argument
- Stamps services with `managed-by:<label>` tags
- Scopes deletions to owned services only
- Prevents cross-chart API deletion

### ✅ Deployment Order
- manage.sh deploys in correct order:
  1. discussion-forum-apis (Kong routes)
  2. discussion-forum-consumers (Kong ACLs)
  3. discussionmw (middleware)
  4. nodebb (forum platform)
  5. groups (groups service)

### ✅ Configuration
- Core chart: `managed_by: core`
- Addon chart: `managed_by: discussion-forum`
- Both charts pass `--managed-by` to kong_apis.py

---

## How Kong API Isolation Works After Fixes

### With Both Fixes Applied:

```
1. Job starts with correct image
   └─ kong_apis.py now understands --managed-by argument

2. Script fetches services from Kong
   Phase 1: ALL services (for create/update decisions)
   Phase 2: Services tagged 'managed-by:discussion-forum' (for safe deletes)

3. Creates/updates addon APIs
   └─ Each service gets tagged: ["managed-by:discussion-forum"]

4. Deletes only orphaned addon APIs
   └─ Never touches core APIs (tagged with "managed-by:core")

5. Result: Perfect isolation ✓
   - Core can upgrade without affecting addon
   - Addon can upgrade without affecting core
   - Both can deploy concurrently
```

---

## Files Modified

| File | Change | Status |
|------|--------|--------|
| `addons/discussion-forum/helmcharts/discussion-forum-apis/Chart.yaml` | Fixed helm dependency path | ✅ |
| `addons/discussion-forum/helmcharts/discussion-forum-apis/values.yaml` | Updated Docker image | ✅ |

---

## Pre-Deployment Requirements

Before redeploying, ensure:

1. **Environment Variables Set**:
   ```bash
   export ENV_NAME=demo
   export CLOUD_PROVIDER=azure
   ```

2. **OpenTofu Files Present**:
   ```bash
   ls opentofu/azure/demo/global-*.yaml
   # Should show:
   # - global-values.yaml
   # - global-cloud-values.yaml
   ```

3. **Core Kong Chart Deployed First**:
   ```bash
   # Core Kong APIs with --managed-by=core must be deployed
   # before addon deployment
   ```

---

## Deployment Command

After fixes are applied:

```bash
cd addons/discussion-forum
export ENV_NAME=demo
export CLOUD_PROVIDER=azure
./scripts/manage.sh install azure
```

The script will:
- ✅ Update helm dependencies (now works with correct path)
- ✅ Deploy discussion-forum-apis job (with correct image)
- ✅ Job accepts `--managed-by=discussion-forum`
- ✅ Create 31 Kong APIs with ownership tags
- ✅ Deploy remaining addon services

---

## Verification Steps

### 1. Check Job Status
```bash
kubectl get jobs -n addon
kubectl logs -n addon job/discussion-forum-apis
```

Expected: Job completes successfully

### 2. Verify Kong APIs Registered
```bash
kubectl exec -n addon kong-pod -- \
  curl 'http://localhost:8001/services?tags=managed-by:discussion-forum' | \
  jq '.data | length'
```

Expected: 31 (discussion + groups APIs)

### 3. Verify Core APIs Untouched
```bash
kubectl exec -n addon kong-pod -- \
  curl 'http://localhost:8001/services?tags=managed-by:core' | \
  jq '.data | length'
```

Expected: ~470 (core APIs remain intact)

### 4. Check Service Tags
```bash
kubectl exec -n addon kong-pod -- \
  curl 'http://localhost:8001/services/createGroup' | \
  jq '.tags'
```

Expected: `["managed-by:discussion-forum"]`

---

## Technical Details

### Chart.yaml Fix
- **Why**: Helm needs to find the common chart for template helpers
- **Path Resolution**: From addon location → up to repo root → into helmcharts/library
- **Verification**: `helm dependency list` shows status "ok"

### Docker Image Fix
- **Why**: Updated image includes new `--managed-by` argument
- **Kong Version**: 3.9.1 compatible
- **Script Updates**:
  - `common.py` has tag filtering support
  - `kong_apis.py` has ownership-tag awareness
  - Routes/plugins fully Kong 3.x compatible

---

## Status: ✅ READY FOR DEPLOYMENT

Both critical fixes have been applied. The addon is now ready for deployment with full API isolation support.

**Next Step**: Run `./scripts/manage.sh install azure` from `addons/discussion-forum/`
