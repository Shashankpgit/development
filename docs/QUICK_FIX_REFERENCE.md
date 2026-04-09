# Quick Fix Reference: Chart.yaml Path Correction

## The Error
```
Error: directory ../../../common not found
```

## Root Cause
The addon chart's `Chart.yaml` had an incorrect relative path to the common chart:
```yaml
# ❌ WRONG - This path doesn't exist
repository: file://../../../common
```

## The Fix
```yaml
# ✅ CORRECT - Points to helmcharts/library/common
repository: file://../../../../helmcharts/library/common
```

## File Changed
- `addons/discussion-forum/helmcharts/discussion-forum-apis/Chart.yaml`

## Why This Works
From the discussion-forum-apis chart location:
```
addons/discussion-forum/helmcharts/discussion-forum-apis/Chart.yaml
  ↓
  ../../../ = addons/  (WRONG - leads to missing directory)
  ../../../../ = workspace/sunbird/spark-installer/sunbird-spark-installer/  (CORRECT)
    → helmcharts/library/common/  (EXISTS ✓)
```

## Verification
```bash
cd addons/discussion-forum/helmcharts/discussion-forum-apis

# Should now succeed
helm dependency update
helm dependency list

# Should show "ok" status
NAME  	VERSION	REPOSITORY                                  	STATUS
common	0.1.0  	file://../../../../helmcharts/library/common	ok
```

## Why This Matters
Without this fix:
- ❌ `helm dependency update` fails
- ❌ `helm install` can't proceed
- ❌ manage.sh deployment blocks

With this fix:
- ✅ Helm dependencies resolve correctly
- ✅ Templates can use common helpers
- ✅ manage.sh deploy_service() succeeds
- ✅ Complete addon deployment works

## Related Files
All other addon charts use the external nimbushubin repository, which is correct:
```yaml
# ✅ CORRECT for groups, discussionmw, nodebb
repository: https://nimbushubin.github.io/helmcharts
```

Only the `discussion-forum-apis` chart needs a local reference to the repo's common chart.
