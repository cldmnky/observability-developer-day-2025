# Perses Dashboard Troubleshooting Guide

This document covers common issues when deploying Perses dashboards with the Cluster Observability Operator.

## Issue: Dashboard Not Showing Up in OpenShift Console

### Symptoms
- PersesDashboard resource exists but doesn't appear in OpenShift Console
- Dashboard status shows `status: Unknown` or stuck in "Reconciling"
- Perses operator logs show errors

### Root Cause Analysis

Check the Perses operator logs:
```bash
oc logs -n openshift-cluster-observability-operator deployment/perses-operator --tail=100
```

Check the dashboard status:
```bash
oc get persesdashboard <dashboard-name> -n openshift-cluster-observability-operator -o yaml
```

## Common Errors

### 1. Invalid Format Units

**Error Message:**
```
spec.yAxis.format.unit: conflicting values "bytes" and "reqps"
spec.yAxis.format.unit: conflicting values "decimal" and "cores"
```

**Problem:** 
Perses TimeSeriesChart plugin has strict validation for format units. Custom units like `reqps`, `cores`, `percent`, etc. are **not allowed**.

**Valid Format Units (as of Perses 0.9.1):**
- `bytes` - For memory, storage, data sizes
- `decimal` - For numeric values, counts, rates
- `seconds` - For time durations
- `milliseconds` - For time durations
- `minutes` - For time durations  
- `hours` - For time durations
- `days` - For time durations
- `weeks` - For time durations
- `months` - For time durations
- `years` - For time durations

**Solution:**
Replace invalid units with valid ones:
```yaml
# ❌ WRONG
yAxis:
  format:
    unit: reqps  # Invalid

# ✅ CORRECT
yAxis:
  format:
    unit: decimal  # Valid - displays numeric values
```

**Examples:**
- Request rate (req/s) → Use `decimal`
- CPU cores → Use `decimal`
- Error percentage → Use `decimal`
- Latency in seconds → Use `seconds`
- Memory bytes → Use `bytes`

### 2. Invalid Stack Values

**Error Message:**
```
spec.visual.stack: conflicting values "all" and "none"
spec.visual.stack: conflicting values "percent" and "none"
```

**Problem:**
The `stack: none` value is causing validation errors with Perses CUE schemas.

**Solution:**
Remove the `stack` field entirely if you don't want stacking:
```yaml
# ❌ WRONG
visual:
  display: line
  stack: none  # This causes errors

# ✅ CORRECT
visual:
  display: line
  # No stack field needed for non-stacked charts
```

Valid stack values (if used):
- `all` - Stack all series
- `percent` - Stack as percentage

### 3. Missing or Incorrect Grid Layout

**Error Message:**
```
"true": 0  # Instead of "y": 0
```

**Problem:**
YAML boolean parsing issue in grid layout items.

**Solution:**
Ensure grid items use proper field names:
```yaml
# ✅ CORRECT
layouts:
  - kind: Grid
    spec:
      items:
        - x: 0
          y: 0      # Not "true": 0
          width: 12
          height: 7
          content:
            $ref: "#/spec/panels/0_0"
```

### 4. Dashboard Not Appearing After Fixing Errors

**Problem:**
Dashboard exists but still doesn't show in UI after corrections.

**Solution:**
1. Delete and recreate the dashboard:
```bash
oc delete persesdashboard <dashboard-name> -n openshift-cluster-observability-operator
oc apply -f <dashboard-file>.yaml
```

2. Wait for reconciliation (usually 5-10 seconds):
```bash
oc get persesdashboard <dashboard-name> -n openshift-cluster-observability-operator -w
```

3. Check status condition:
```bash
oc get persesdashboard <dashboard-name> -n openshift-cluster-observability-operator -o jsonpath='{.status.conditions[0]}' | jq
```

Expected successful status:
```json
{
  "lastTransitionTime": "2025-10-13T13:07:05Z",
  "message": "Dashboard (observability-demo-overview) created successfully",
  "reason": "Reconciling",
  "status": "True",
  "type": "Available"
}
```

## Validation Before Deployment

### 1. Check API Version Support
```bash
oc api-versions | grep perses
```

Should return: `perses.dev/v1alpha1`

### 2. Verify Perses Operator is Running
```bash
oc get pods -n openshift-cluster-observability-operator | grep perses
```

Expected output:
```
perses-0                                                     1/1     Running
perses-operator-54dc79bbcc-xxxxx                             1/1     Running
```

### 3. Test Datasource Connection
```bash
# Check datasource status
oc get persesdatasource -n openshift-cluster-observability-operator

# Verify datasource condition
oc get persesdatasource <datasource-name> -n openshift-cluster-observability-operator -o jsonpath='{.status.conditions[0]}' | jq
```

### 4. Dry-Run Validation
```bash
oc apply --dry-run=client -f <dashboard-file>.yaml
```

## Debugging Workflow

1. **Check if dashboard resource exists:**
   ```bash
   oc get persesdashboard -n openshift-cluster-observability-operator
   ```

2. **View dashboard status:**
   ```bash
   oc describe persesdashboard <dashboard-name> -n openshift-cluster-observability-operator
   ```

3. **Check Perses operator logs:**
   ```bash
   oc logs -n openshift-cluster-observability-operator deployment/perses-operator --tail=50 | grep -i error
   ```

4. **Check Perses backend logs:**
   ```bash
   oc logs -n openshift-cluster-observability-operator perses-0 --tail=50 | grep -i "status=400"
   ```

5. **Verify datasource connectivity:**
   ```bash
   # Check if Thanos Querier is reachable
   oc run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -s http://thanos-querier-observability-stack.observability-demo.svc.cluster.local:10902/api/v1/query?query=up
   ```

## Common Fixes Summary

| Issue | Fix |
|-------|-----|
| Invalid format units | Use only: `decimal`, `bytes`, `seconds`, `milliseconds`, `minutes`, `hours`, `days`, `weeks`, `months`, `years` |
| Stack validation error | Remove `stack` field or use `all`/`percent` |
| Dashboard stuck reconciling | Delete and recreate dashboard |
| 400 Bad Request | Check operator logs for CUE validation errors |
| Datasource not found | Verify datasource exists in same namespace |
| Grid layout errors | Ensure proper `x`, `y`, `width`, `height` fields |

## Reference Documentation

- [Perses Operator GitHub](https://github.com/perses/perses-operator)
- [Perses CUE Schemas](https://github.com/perses/perses/tree/main/cue)
- [COO Perses Guide](https://github.com/rhobs/observability-operator/blob/main/docs/user-guides/perses-dashboards.md)
- [TimeSeriesChart Plugin Schema](https://github.com/perses/perses/blob/main/plugins/timeserieschart/schemas/time-series.cue)

## Tested Configuration

The following configuration has been validated and works correctly:

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDashboard
metadata:
  name: observability-demo-overview
  namespace: openshift-cluster-observability-operator
spec:
  display:
    name: "My Dashboard"
  duration: 1h
  panels:
    "0_0":
      kind: Panel
      spec:
        display:
          name: "Panel Title"
        plugin:
          kind: TimeSeriesChart
          spec:
            legend:
              mode: list
              position: bottom
            visual:
              display: line
              lineWidth: 1
              # NO stack field for simple line charts
            yAxis:
              format:
                unit: decimal  # ✅ Valid unit
              min: 0
        queries:
          - kind: TimeSeriesQuery
            spec:
              plugin:
                kind: PrometheusTimeSeriesQuery
                spec:
                  datasource:
                    kind: PrometheusDatasource
                    name: my-datasource
                  query: 'up{}'
  layouts:
    - kind: Grid
      spec:
        items:
          - x: 0
            y: 0
            width: 12
            height: 7
            content:
              $ref: "#/spec/panels/0_0"
```

## Last Updated

October 13, 2025 - Based on Perses Operator v0.9.1 running in OpenShift 4.x with COO 1.2+
