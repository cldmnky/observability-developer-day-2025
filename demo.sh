#!/bin/bash
# Live Demo Script
# This script walks through the demo steps with pauses and explanations
# Estimated time: 10-12 minutes

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to pause and wait for user
pause() {
    echo ""
    echo -e "${CYAN}Press ENTER to continue...${NC}"
    read -r
}

# Function to show step header
step() {
    echo ""
    echo "========================================="
    echo -e "${BLUE}$1${NC}"
    echo "========================================="
    echo ""
}

# Check if redhatsay is available
HAS_REDHATSAY=false
if command -v redhatsay &> /dev/null; then
    HAS_REDHATSAY=true
fi

# Function to explain what we're doing
explain() {
    if [ "$HAS_REDHATSAY" = true ]; then
        redhatsay "📝 $1"
    else
        echo -e "${YELLOW}📝 $1${NC}"
    fi
    echo ""
}

# Function to run command with explanation
run_cmd() {
    echo -e "${GREEN}$ $1${NC}"
    eval "$1"
}

clear
echo "========================================="
echo "  OpenShift Observability Demo"
echo "  Auto-Instrumentation in Action"
echo "========================================="
echo ""
echo "Demo Flow (10-12 minutes):"
echo "  1. Deploy Applications (2 min)"
echo "  2. Enable Metrics Collection (2 min)"
echo "  3. Enable Distributed Tracing (4 min)"
echo "  4. Visualize & Query (2-4 min)"
echo ""

pause

# ==========================================
# PHASE 1: DEPLOY APPLICATIONS
# ==========================================

step "Phase 1: Deploy Applications"

explain "We have 4 microservices:"
echo "  • Go API (port 4001) - Name generator"
echo "  • Python API (port 4004) - Seed generator with variable latency"
echo "  • Quarkus API (port 4003) - Lolcat colorizer"
echo "  • Node.js App (port 3000) - Web frontend + background worker"
echo ""
explain "⚡ Key point: NO OpenTelemetry code in any of these apps!"

pause

explain "Deploying all 4 applications..."
run_cmd "oc apply -f manifests/1-apps/"

echo ""
explain "Waiting for demo app pods to be ready..."
run_cmd "oc wait --for=condition=Ready pods -l demo=observability -n observability-demo --timeout=120s"

echo ""
run_cmd "oc get pods -l demo=observability -n observability-demo"

pause

explain "Let's prove there's no instrumentation code..."
echo "Checking Python app for OpenTelemetry imports:"
run_cmd "oc exec -n observability-demo deployment/python-api -- cat /app/app.py | grep -i 'otel\\|telemetry' || echo 'No OpenTelemetry code found! ✓'"

pause

explain "Getting the web app URL..."
ROUTE=$(oc get route node-app -n observability-demo -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$ROUTE" ]; then
    echo -e "${GREEN}🌐 Web UI: https://$ROUTE${NC}"
    echo ""
    echo "👉 Open this in your browser and generate some names!"
else
    echo "Route not found, creating..."
    oc create route edge node-app --service=node-app -n observability-demo
    ROUTE=$(oc get route node-app -n observability-demo -o jsonpath='{.spec.host}')
    echo -e "${GREEN}🌐 Web UI: https://$ROUTE${NC}"
fi

pause

# ==========================================
# PHASE 2: ENABLE METRICS COLLECTION
# ==========================================

step "Phase 2: Enable Metrics Collection"

explain "ServiceMonitors tell Prometheus what to scrape."
echo "Each ServiceMonitor has the label: monitoring.rhobs/stack: observability-stack"
echo "Prometheus discovers them via label selector."

pause

explain "Deploying ServiceMonitors for all applications..."
run_cmd "oc apply -f manifests/3-servicemonitors/"

echo ""
run_cmd "oc get servicemonitors.monitoring.rhobs -n observability-demo"

pause

explain "Checking Prometheus targets..."
echo "Opening port-forward to Prometheus (Ctrl+C to close)..."
echo "Visit: http://localhost:9090/targets"
echo ""
echo "You should see all 4 application targets as UP!"

oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090 &
PF_PID=$!
sleep 3

echo ""
echo -e "${GREEN}Prometheus UI: http://localhost:9090${NC}"
echo ""
echo "Try these queries:"
echo "  • up{namespace=\"observability-demo\"}"
echo "  • rate(http_server_duration_milliseconds_count[5m])"
echo "  • process_resident_memory_bytes{namespace=\"observability-demo\"}"

pause

# Kill port-forward
kill $PF_PID 2>/dev/null || true

# ==========================================
# PHASE 3: ENABLE DISTRIBUTED TRACING  
# ==========================================

step "Phase 3: Enable Distributed Tracing"

explain "Step 1: Deploy RBAC for OpenTelemetry collectors"
run_cmd "oc apply -f manifests/4-opentelemetry/rbac.yaml"
run_cmd "oc apply -f manifests/4-opentelemetry/tempo-writer-rbac.yaml"

pause

explain "Step 2: Deploy auto-instrumentation configuration"
echo "This defines how to instrument each language (Python, Node.js, Java, Go)"
run_cmd "oc apply -f manifests/4-opentelemetry/instrumentation.yaml"

echo ""
run_cmd "oc get instrumentation -n observability-demo"

pause

explain "Step 3: Deploy sidecar collector"
echo "Runs alongside each app pod, receives OTLP from the app"
run_cmd "oc apply -f manifests/4-opentelemetry/sidecar-collector.yaml"

pause

explain "Step 4: Deploy central collector"
echo "Aggregates telemetry, generates RED metrics, exports to Tempo/Prometheus"
run_cmd "oc apply -f manifests/4-opentelemetry/central-collector.yaml"

echo ""
explain "Waiting for central collector to be ready..."
sleep 5
run_cmd "oc wait --for=condition=Ready pods -l app.kubernetes.io/component=opentelemetry-collector -n observability-demo --timeout=120s || echo 'Note: Collector pods may take a moment to appear'"

pause

explain "Step 5: Enable auto-instrumentation via annotations"
echo "⚡ This is the ONLY change to the deployments!"
echo ""
echo "Adding to each deployment:"
echo "  1. Service account: otel-collector-sidecar"
echo "  2. Annotation: sidecar.opentelemetry.io/inject: sidecar"
echo "  3. Annotation: instrumentation.opentelemetry.io/inject-<lang>: demo-instrumentation"

pause

explain "Patching go-api deployment..."
run_cmd "oc patch deployment go-api -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

explain "Patching python-api deployment..."
run_cmd "oc patch deployment python-api -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\",\"instrumentation.opentelemetry.io/inject-python\":\"demo-instrumentation\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

explain "Patching quarkus-api deployment..."
run_cmd "oc patch deployment quarkus-api -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\",\"instrumentation.opentelemetry.io/inject-java\":\"demo-instrumentation\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

explain "Patching node-app deployment..."
run_cmd "oc patch deployment node-app -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\",\"instrumentation.opentelemetry.io/inject-nodejs\":\"demo-instrumentation\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

echo ""
explain "Waiting for demo app pods to restart with instrumentation..."
sleep 10
run_cmd "oc wait --for=condition=Ready pods -l demo=observability -n observability-demo --timeout=120s"

pause

explain "Verifying instrumentation..."
echo "Each pod should now have 2 containers: app + sidecar (otc-container)"
run_cmd "oc get pods -l demo=observability -n observability-demo"

echo ""
echo "Checking OTEL environment variables in python-api:"
run_cmd "oc exec -n observability-demo deployment/python-api -c python-api -- env | grep OTEL_ | head -5"

pause

# ==========================================
# PHASE 4: VISUALIZE & QUERY
# ==========================================

step "Phase 4: Visualize & Query"

explain "Deploying Perses datasource and dashboard..."
run_cmd "oc apply -f manifests/5-coo-setup/perses-datasource.yaml"
run_cmd "oc apply -f manifests/5-coo-setup/working-dashboard.yaml"

pause

explain "Opening Jaeger UI to view traces..."
echo "Port-forwarding to Tempo Query Frontend (Ctrl+C to close)..."
echo ""
echo "Visit: http://localhost:16686"
echo "  1. Select service: node-app"
echo "  2. Click 'Find Traces'"
echo "  3. Explore distributed traces across services!"

oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686 &
PF_PID=$!
sleep 3

echo ""
echo -e "${GREEN}Jaeger UI: http://localhost:16686${NC}"

pause

# Kill port-forward
kill $PF_PID 2>/dev/null || true

explain "Checking RED metrics auto-generated from traces..."
echo "Opening Prometheus..."
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090 &
PF_PID=$!
sleep 3

echo ""
echo -e "${GREEN}Prometheus UI: http://localhost:9090${NC}"
echo ""
echo "Try these queries:"
echo ""
echo "Request rate per service:"
echo "  sum by (service_name) (rate(http_server_duration_milliseconds_count{k8s_namespace_name=\"observability-demo\"}[5m]))"
echo ""
echo "P95 latency:"
echo "  histogram_quantile(0.95, sum by (service_name, le) (rate(http_server_duration_milliseconds_bucket{k8s_namespace_name=\"observability-demo\"}[5m])))"

pause

# Kill port-forward
kill $PF_PID 2>/dev/null || true

explain "Opening OpenShift Console..."
CONSOLE=$(oc whoami --show-console)
echo -e "${GREEN}OpenShift Console: $CONSOLE${NC}"
echo ""
echo "Navigate to:"
echo "  • Observe → Metrics (Perses dashboard)"
echo "  • Observe → Traces (Distributed Tracing UI)"

pause

# ==========================================
# DEMO COMPLETE
# ==========================================

clear
echo "========================================="
echo "  🎉 Demo Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}What we accomplished:${NC}"
echo "  ✓ Deployed 4 microservices (0 lines of OTel code)"
echo "  ✓ Enabled metrics collection (ServiceMonitors)"
echo "  ✓ Enabled distributed tracing (annotations + service account)"
echo "  ✓ Auto-generated RED metrics from traces"
echo "  ✓ Integrated everything in OpenShift Console"
echo ""
echo -e "${GREEN}Key Takeaways:${NC}"
echo "  • Zero code changes required"
echo "  • Polyglot support (Go, Python, Java, Node.js)"
echo "  • Automatic trace-to-metric correlation"
echo "  • OpenShift-native observability"
echo "  • Production-ready with Tempo + Prometheus"
echo ""
echo -e "${CYAN}Time to observability: ~10 minutes${NC}"
echo -e "${CYAN}Lines of code changed: 0${NC}"
echo -e "${CYAN}Manifest changes: 2-3 annotations + service account per deployment${NC}"
echo ""
echo "========================================="
echo ""
echo "Resources:"
echo "  • Web App: https://$ROUTE"
echo "  • OpenShift Console: $CONSOLE"
echo "  • Cleanup script: ./demo-cleanup.sh"
echo ""
