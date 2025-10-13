# Quick Trace Verification Guide

## ✅ Current Status
**All components are operational with 0 errors!**

## Access Traces UI

### OpenShift Console
1. Open: https://console-openshift-console.apps.borg.blahonga.me
2. Navigate to: **Observe → Traces**
3. Select:
   - **TempoStack**: `tempo (openshift-tempo-operator)`
   - **Tenant**: `dev`
4. Query traces by service name, time range, or tags

## Generate Test Traffic

```bash
# Send requests to create traces
for i in {1..10}; do 
  curl -s http://node-app-observability-demo.apps.borg.blahonga.me/ > /dev/null
  echo "Request $i sent"
  sleep 1
done
```

## Verify Configuration

### Check Collector (should show 0 errors)
```bash
oc logs -n observability-demo deployment/central-collector --since=2m | grep -i error
```

### Check Application Pods (should show 2/2 containers)
```bash
oc get pods -n observability-demo | grep -E "go-api|python-api|quarkus-api|node-app"
```

### Verify Auto-Instrumentation
```bash
# Check node-app pod for instrumentation init container
oc get pod -n observability-demo -l app=node-app -o jsonpath='{.items[0].spec.initContainers[*].name}'
# Should show: otc-container opentelemetry-auto-instrumentation-nodejs
```

## Key Configuration Values

- **Tempo Gateway Endpoint**: `tempo-tempo-gateway.openshift-tempo-operator.svc:8090`
- **Tenant**: `dev` (ID: `1610b0c3-c509-4592-a256-a1871353dbfa`)
- **Auth**: Bearer token from service account `otel-central-collector`
- **TLS**: Service CA certificate at `/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt`

## Troubleshooting

### No traces appearing?
1. Refresh the OpenShift Console traces UI
2. Adjust time range to "Last 15 minutes"
3. Try searching by service name: `node-app`, `go-api`, `python-api`, or `quarkus-api`
4. Check collector logs for errors (see verification commands above)

### Still not working?
Check the detailed documentation: `manifests/3-opentelemetry/TRACES_CONFIGURATION_COMPLETE.md`
