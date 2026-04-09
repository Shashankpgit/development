# Deployment Error Fix: Docker Image Update

## Problem Encountered
When running `./scripts/manage.sh install`, the discussion-forum-apis job failed with:
```
kong_apis.py: error: unrecognized arguments: --managed-by=discussion-forum
```

## Root Cause
The addon's `values.yaml` was using an outdated Docker image that doesn't support the `--managed-by` argument:

```yaml
# ❌ OLD (didn't support --managed-by)
image:
  repository: shashank04515/kong-scripts
  tag: "local-upsert"
```

This image only supported the `--upsert-only` flag, which is not part of the new ownership-tag-based architecture.

## Solution Applied
Updated the addon image to match the core chart's image, which includes the `--managed-by` support:

```yaml
# ✅ NEW (supports --managed-by)
image:
  repository: sunbirded.azurecr.io/kong-scripts
  tag: "0.1.8"
```

## File Changed
- `addons/discussion-forum/helmcharts/discussion-forum-apis/values.yaml`

## Why This Fix Works

The `sunbirded.azurecr.io/kong-scripts:0.1.8` image contains the updated `kong_apis.py` script with these features:

1. **Added `--managed-by` argument support** (lines 452-457 in kong_apis.py)
2. **Two-phase fetch strategy**:
   - Phase 1: Fetch ALL services (for create/update decision)
   - Phase 2: Fetch ONLY owned services tagged with `managed-by:` label (for safe delete)
3. **Ownership tag stamping** (line 124 in kong_apis.py)
4. **Kong 3.9.1 compatibility** with proper service/route/plugin handling

## Verification

After the fix, the job should:
1. ✅ Accept the `--managed-by=discussion-forum` argument
2. ✅ Fetch services tagged with `managed-by:discussion-forum`
3. ✅ Create new services with the ownership tag
4. ✅ Update existing services and stamp the tag
5. ✅ Only delete services it owns (tagged with discussion-forum tag)
6. ✅ Leave core services untouched (tagged with core tag)

## Next Steps

1. **Redeploy the addon** with the fixed image:
   ```bash
   cd addons/discussion-forum
   export ENV_NAME=demo
   export CLOUD_PROVIDER=azure
   ./scripts/manage.sh install azure
   ```

2. **Verify the job succeeds**:
   ```bash
   kubectl get jobs -n addon
   kubectl logs -n addon job/discussion-forum-apis
   ```

3. **Confirm Kong APIs are registered**:
   ```bash
   kubectl exec -n addon kong-pod -- \
     curl 'http://localhost:8001/services?tags=managed-by:discussion-forum' | \
     jq '.data | length'
   # Expected: 31
   ```

## Summary

| Aspect | Status |
|--------|--------|
| **Problem** | Old image didn't support `--managed-by` argument |
| **Solution** | Updated to core image with `--managed-by` support |
| **File Changed** | `addons/discussion-forum/helmcharts/discussion-forum-apis/values.yaml` |
| **Impact** | Addon can now use ownership-tag-based API isolation |
| **Status** | ✅ FIXED - Ready to redeploy |
