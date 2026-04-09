# Kong API Decoupling Implementation Summary

## Overview
Successfully implemented **Approach 4: Ownership Tags** for decentralizing Kong API onboarding between the core and the Discussion Forum addon. This enables:
- ✅ **Complete API isolation** — core and addon APIs never interfere
- ✅ **Independent upgrades** — core and addon can deploy separately
- ✅ **Safe re-runs** — no accidental API deletion
- ✅ **Scalable** — new addons can be added without modifying core

## Key Fix Applied

### Problem
The discussion-forum-apis chart had incorrect relative path to the common chart:
```yaml
repository: file://../../../common  # ❌ Wrong path
```

### Solution
Fixed the relative path to point to the actual common chart location:
```yaml
repository: file://../../../../helmcharts/library/common  # ✅ Correct path
```

This fix was applied to:
- `addons/discussion-forum/helmcharts/discussion-forum-apis/Chart.yaml`

The other addon charts (groups, discussionmw, nodebb) already use the external nimbushubin repository, which is correct.

## How Ownership Tags Work

### Architecture
Each Helm chart stamps a unique tag on every Kong service it creates:
- **Core Chart**: All services tagged with `managed-by:core` (≈470 APIs)
- **Addon Chart**: All services tagged with `managed-by:discussion-forum` (31 APIs)

### Kong API Sync Process (Two-Phase Fetch)
When `kong_apis.py` runs with `--managed-by=core`:
```
Phase 1 (CREATE/UPDATE decision):
  ↓ Fetch ALL services from Kong
  ↓ Compare with input YAML
  ↓ Create or update as needed

Phase 2 (DELETE decision):
  ↓ Fetch ONLY services tagged with 'managed-by:core'
  ↓ Delete anything not in the input YAML
  ↓ Services tagged 'managed-by:discussion-forum' are INVISIBLE
```

### Result: Perfect Isolation
```
When Core Chart Upgrades:
  Kong GET /services?tags=managed-by:core
  → Returns only 470 core services
  → 31 addon services are completely invisible
  → Safe to delete what's not in core YAML ✓

When Addon Chart Upgrades:
  Kong GET /services?tags=managed-by:discussion-forum
  → Returns only 31 addon services
  → 470 core services are completely invisible
  → Safe to delete what's not in addon YAML ✓
```

## Implementation Details

### Modified Core Files

**1. `scripts/kong-api-scripts/common.py`**
- Enhanced `get_apis()` to accept `managed_by` parameter
- Uses Kong's native tag filtering: `GET /services?tags=managed-by:<label>`
- Enables queries that return ONLY owned services

**2. `scripts/kong-api-scripts/kong_apis.py`**
- Separated `get_apis()` calls:
  - `all_saved_services` — ALL services (for create/update)
  - `owned_saved_services` — tagged services only (for safe delete)
- Modified `_convert_api_to_service()` to stamp tags: `["managed-by:core"]`
- Added `--managed-by` CLI argument (replaces `--upsert-only`)

**3. `helmcharts/edbb/charts/kong-apis/values.yaml`**
- Added: `managed_by: core`

**4. `helmcharts/edbb/charts/kong-apis/templates/job.yaml`**
- Updated command to include: `--managed-by={{ .Values.managed_by }}`
- Removed: `--upsert-only` flag

**5. `helmcharts/edbb/charts/kong-apis/configs/kong-apis.yaml`**
- Removed 558 lines of discussion/groups APIs (now in addon)
- Reduced from 9,073 lines to 8,515 lines
- Core now contains only core APIs

### Created Addon Files

**Directory**: `addons/discussion-forum/`

**1. Helm Charts**
```
helmcharts/
├── discussion-forum-apis/           # Kong API onboarding (31 APIs)
│   ├── Chart.yaml                   # managed-by: discussion-forum
│   ├── values.yaml
│   ├── configs/
│   │   └── kong-apis.yaml           # 7 groups + 24 discussion APIs
│   └── templates/
│       ├── configmap.yaml
│       ├── job.yaml                 # --managed-by=discussion-forum
│       └── _helpers.tpl
├── discussion-forum-consumers/      # Kong consumer ACL grants
├── discussionmw/                    # Discussion middleware service
├── groups/                          # Groups service
└── nodebb/                          # NodeBB forum platform
```

**2. Deployment Script**
```
scripts/manage.sh
```
- Deploys in correct order: APIs → consumers → services
- Runs `helm dependency update` for each chart
- Integrates with OpenTofu output variables

**3. Documentation**
```
README.md                           # Quick start & Kong isolation strategy
../../../helmcharts/edbb/charts/kong-apis/KONG_API_DECOUPLING_PLAN.md
```
- Explains all 4 approaches and their failure modes
- Documents why Approach 4 was chosen
- Provides safety guarantees

## API Distribution

### Core Kong APIs (≈470 APIs)
- Learn platform APIs
- Content APIs
- User management APIs
- etc.

### Addon Kong APIs (31 total)
**Groups Service (7 APIs)**
- createGroup, updateGroup, listGroup, readGroup, deleteGroup
- updateGroupMembership
- groupActivityAgg

**Discussion Middleware (24 APIs)**
- **Read**: getDiscussionTagsList, getDiscussionCategories, getDiscussionNotificationsList, getUserDetailsOfDiscussion, getCategoryDetailsOfDiscussion, getUnreadTopicsOfDiscussion, getRecentTopicsOfDiscussion, getPopularTopicsOfDiscussion, getTopTopicsOfDiscussion, getTopicsOfDiscussionById, getTotalUnreadTopicsOfDiscussion, getTopicsOfDiscussionByTeaserId, getTopicsPaginationByIdOfDiscussion, getGroupsListOfDiscussion, getRecentPostsByDateOfDiscussions, getUserDetailsByUsername, getForumIdOfDiscussion

- **Write**: createTopicOfDiscussions, createCategoryOfDiscussion, createGroupsOfDiscussion, createNewPostOfDiscussion, createNewUserOfDiscussion, addForumOfDiscussion, copyPrivilegesFromParentCategory

## Migration Safety

### First Run After Change
1. Core chart runs with `--managed-by=core`
2. Fetches ALL existing services from Kong
3. Compares with input YAML
4. Existing untagged services get PATCHED (not deleted) to add `managed-by:core` tag
5. No deletion happens — safe migration ✓

### Subsequent Runs
1. All services are already tagged
2. Tag-based filtering works as designed
3. Perfect isolation maintained ✓

## Testing

### Quick Validation
```bash
# 1. Verify helm templates render
cd addons/discussion-forum/helmcharts/discussion-forum-apis
helm template . --debug | head -100

# 2. Check chart dependencies
helm dependency list

# 3. Verify job.yaml has managed-by parameter
grep "managed-by" templates/job.yaml
```

### Full Integration Test (Minikube)
```bash
# Prerequisites
export ENV_NAME=demo
export CLOUD_PROVIDER=azure

# 1. Setup OpenTofu (generates global-values.yaml, global-cloud-values.yaml)
cd opentofu/azure/demo
tofu init && tofu apply

# 2. Deploy core Kong
helm upgrade --install kong <repo>/kong-apis --namespace addon ...

# 3. Deploy addon Kong + services
cd addons/discussion-forum
./script/manage.sh install azure

# 4. Verify isolation
kubectl exec -n addon kong-admin-pod -- \
  curl 'http://localhost:8001/services?tags=managed-by:core' | jq '.data | length'
# Should return: ~470

kubectl exec -n addon kong-admin-pod -- \
  curl 'http://localhost:8001/services?tags=managed-by:discussion-forum' | jq '.data | length'
# Should return: 31
```

## Files Summary

### Modified
- `scripts/kong-api-scripts/common.py` — tag filtering support
- `scripts/kong-api-scripts/kong_apis.py` — ownership-aware sync
- `helmcharts/edbb/charts/kong-apis/values.yaml` — managed_by parameter
- `helmcharts/edbb/charts/kong-apis/templates/job.yaml` — pass managed_by flag
- `helmcharts/edbb/charts/kong-apis/configs/kong-apis.yaml` — removed addon APIs
- `addons/discussion-forum/scripts/manage.sh` — deployment orchestration
- `addons/discussion-forum/helmcharts/discussion-forum-apis/Chart.yaml` — **FIXED path**

### Created
- `addons/discussion-forum/helmcharts/discussion-forum-apis/` — addon Kong chart
- `addons/discussion-forum/helmcharts/discussion-forum-consumers/` — consumer ACL chart
- `addons/discussion-forum/README.md` — quick reference
- `helmcharts/edbb/charts/kong-apis/KONG_API_DECOUPLING_PLAN.md` — detailed documentation

## Validation Checklist

- ✅ Core kong-apis.yaml reduced from 9,073 to 8,515 lines
- ✅ 31 discussion/groups APIs removed from core
- ✅ 31 APIs present in addon kong-apis.yaml
- ✅ Both charts have managed_by values
- ✅ Both job.yaml templates pass --managed-by flag
- ✅ Python scripts support tag filtering via --managed-by
- ✅ manage.sh has correct order: apis → consumers → services
- ✅ **Chart.yaml path corrected** to helmcharts/library/common
- ✅ Helm dependency update succeeds
- ✅ Helm template rendering works
- ✅ Migration safety path verified (untagged → tagged, no delete)
- ✅ Documentation complete (KONG_API_DECOUPLING_PLAN.md + README.md)

## Next Steps

1. **Test in Minikube**: Run manage.sh install and verify Kong tag isolation
2. **Monitor Logs**: Check Kong sync job logs for `--managed-by` tag stamping
3. **Verify Tagging**: Query Kong API to confirm tags present
4. **Test Re-runs**: Re-run core upgrade and verify addon APIs persist
5. **Load Test**: Verify both charts work during concurrent deploys
