#!/bin/bash
# Live Demo Script
# This script walks through the demo steps with pauses and explanations
# Estimated time: 10-12 minutes

########################
# include the magic
########################
. scripts/demo-magic.sh

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to show step header
step() {
    clear
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

# Check if bat is available
HAS_BAT=false
if command -v bat &> /dev/null; then
    HAS_BAT=true
fi

# Check if gum is available
HAS_GUM=false
if command -v gum &> /dev/null; then
    HAS_GUM=true
fi

# Function to explain what we're doing
explain() {
    if [ "$HAS_REDHATSAY" = true ]; then
        redhatsay "$1"
    else
        echo -e "${YELLOW}$1${NC}"
    fi
    echo ""
}

# Function to show YAML with syntax highlighting
show_yaml() {
    local file=$1
    local description=$2
    
    clear
    if [ -n "$description" ]; then
        explain "$description"
    fi
    
    if [ "$HAS_BAT" = true ]; then
        bat --style=plain --color=always --language=yaml --paging=always "$file"
    elif [ "$HAS_GUM" = true ]; then
        gum format -t code -l yaml < "$file"
        echo ""
        echo "Press ENTER to continue..."
        read -r
    else
        less -R "$file"
    fi
    clear
}

clear
explain "Let's do some OpenShift Observability magic 🎩 with Auto-Instrumentation! ✨"
p ""
clear

cat << 'EOF'
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Browser                                  │
│                                                                         │
│                    https://node-app-route.apps.cluster.com              │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    observability-demo namespace                         │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                       Node.js Web App                           │    │
│  │                          (port 3000)                            │    │
│  │                                                                 │    │
│  │  • Web UI with terminal emulator                                │    │
│  │  • Proxies requests to backend APIs                             │    │
│  │  • Background worker: Python API → Go API (continuous polling)  │    │
│  └────────┬────────────────────┬────────────────────┬──────────────┘    │
│           │                    │                    │                   │
│           ▼                    ▼                    ▼                   │
│  ┌────────────────┐   ┌─────────────────┐   ┌───────────────────────┐   │
│  │   Go API       │   │  Python API     │   │   Quarkus API         │   │
│  │   (port 8080)  │   │  (port 8000)    │   │   (port 4003)         │   │
│  │                │   │                 │   │                       │   │
│  │ • Name gen     │   │ • Seed gen      │   │ • Lolcat colorize     │   │
│  │ • ASCII art    │   │ • Random delay  │   │ • Rainbow ANSI        │   │
│  │ • /metrics     │   │ • /metrics      │   │ • /metrics            │   │
│  └────────────────┘   └─────────────────┘   └───────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
EOF
wait
clear
echo ""
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

wait

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

wait

explain "Let's look at one of the deployments first..."
show_yaml "manifests/1-apps/python-api-deployment.yaml" "📄 Python API Deployment - Notice: No instrumentation annotations yet!"

explain "Deploying all 4 applications..."
pei "oc apply -f manifests/1-apps/"

echo ""
explain "Waiting for demo app pods to be ready..."
pei "oc wait --for=condition=Ready pods -l demo=observability -n observability-demo --timeout=120s"

echo ""
pei "oc get pods -l demo=observability -n observability-demo"

wait
clear

explain "Let's prove there's no instrumentation code..."
echo "Checking Python app for OpenTelemetry imports:"
pei "oc exec -n observability-demo deployment/python-api -- cat /app/app.py | grep -i 'otel\\|telemetry' || echo 'No OpenTelemetry code found! ✓'"

wait
clear

explain "Getting the web app URL..."
ROUTE=$(oc get route node-app -n observability-demo -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$ROUTE" ]; then
    echo -e "${GREEN}🌐 Web UI: https://$ROUTE${NC}"
    echo ""
    echo "👉 Open this in your browser and generate some names!"
    wait
    open "https://$ROUTE"
else
    echo "Route not found, creating..."
    oc create route edge node-app --service=node-app -n observability-demo
    ROUTE=$(oc get route node-app -n observability-demo -o jsonpath='{.spec.host}')
    echo -e "${GREEN}🌐 Web UI: https://$ROUTE${NC}"
fi

wait

# ==========================================
# PHASE 2: ENABLE METRICS COLLECTION
# ==========================================

step "Phase 2: Enable Metrics Collection"

explain "ServiceMonitors tell Prometheus what to scrape."
echo "Each ServiceMonitor has the label: monitoring.rhobs/stack: observability-stack"
echo "Prometheus discovers them via label selector."

wait

explain "Let's look at a ServiceMonitor definition..."
show_yaml "manifests/3-servicemonitors/python-api-servicemonitor.yaml" "📄 ServiceMonitor - Notice the label selector and endpoint configuration"

explain "Deploying ServiceMonitors for all applications..."
pei "oc apply -f manifests/3-servicemonitors/"

echo ""
pei "oc get servicemonitors.monitoring.rhobs -n observability-demo"

wait
clear

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
wait
open "http://localhost:9090"

wait

# Kill port-forward
kill $PF_PID 2>/dev/null || true
clear

# ==========================================
# PHASE 3: ENABLE DISTRIBUTED TRACING  
# ==========================================

step "Phase 3: Enable Distributed Tracing"

explain "Here's how the observability stack architecture works:"
p ""
cat << 'EOF' | less -R
┌─────────────────────────────────────────────────────────────────────────────┐
│                      APPLICATION PODS (observability-demo)                  │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   go-api    │  │ python-api  │  │ quarkus-api │  │  node-app   │         │
│  │             │  │             │  │             │  │             │         │
│  │  [app code] │  │  [app code] │  │  [app code] │  │  [app code] │         │
│  │      ↓      │  │      ↓      │  │      ↓      │  │      ↓      │         │
│  │ Auto-Instr  │  │ Auto-Instr  │  │ Auto-Instr  │  │ Auto-Instr  │         │
│  │   (init)    │  │   (init)    │  │   (init)    │  │   (init)    │         │
│  │      ↓      │  │      ↓      │  │      ↓      │  │      ↓      │         │
│  │   OTLP →    │  │   OTLP →    │  │   OTLP →    │  │   OTLP →    │         │
│  │  localhost  │  │  localhost  │  │  localhost  │  │  localhost  │         │
│  │    :4318    │  │    :4318    │  │    :4318    │  │    :4318    │         │
│  │      ↓      │  │      ↓      │  │      ↓      │  │      ↓      │         │
│  │  [Sidecar]  │  │  [Sidecar]  │  │  [Sidecar]  │  │  [Sidecar]  │         │
│  │  Collector  │  │  Collector  │  │  Collector  │  │  Collector  │         │
│  │  :4317/:18  │  │  :4317/:18  │  │  :4317/:18  │  │  :4317/:18  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                │                │
│         └────────────────┴────────────────┴────────────────┘                │
│                                  │                                          │
│                                  ▼                                          │
│                    ┌──────────────────────────────┐                         │
│                    │   Central Collector          │                         │
│                    │   (Deployment, 2 replicas)   │                         │
│                    │                              │                         │
│                    │  Receives: OTLP gRPC/HTTP    │                         │
│                    │  Processes:                  │                         │
│                    │   • Resource detection       │                         │
│                    │   • K8s attributes           │                         │
│                    │   • Batching                 │                         │
│                    │                              │                         │
│                    │  Connectors:                 │                         │
│                    │   • Span→Metrics (RED)       │                         │
│                    │                              │                         │
│                    │  Exports:                    │                         │
│                    │   • Traces → Tempo           │                         │
│                    │   • Metrics → Prometheus     │                         │
│                    └───────┬──────────────┬───────┘                         │
│                            │              │                                 │
└────────────────────────────┼──────────────┼─────────────────────────────────┘
                             │              │
            ┌────────────────┘              └──────────────────┐
            ▼                                                  ▼
┌───────────────────────────┐                  ┌─────────────────────────────┐
│  openshift-tempo-operator │                  │   observability-demo        │
│                           │                  │                             │
│  ┌─────────────────────┐  │                  │  ┌───────────────────────┐  │
│  │    TempoStack       │  │                  │  │   MonitoringStack     │  │
│  │                     │  │                  │  │                       │  │
│  │  • Distributor      │  │                  │  │  • Prometheus (x3)    │  │
│  │  • Ingester         │  │                  │  │  • Alertmanager (x2)  │  │
│  │  • Querier          │  │                  │  │  • Thanos Querier     │  │
│  │  • Query Frontend   │  │                  │  │                       │  │
│  │                     │  │                  │  │  ServiceMonitors:     │  │
│  │  Storage: MinIO S3  │  │                  │  │   • go-api            |  │
│  │  Retention: 48h     │  │                  │  │   • python-api        │  │
│  │  Tenants: dev,prod  │  │                  │  │   • quarkus-api       │  │
│  │                     │  │                  │  │   • node-app          │  │
│  │  Jaeger UI: ✓       │  │                  │  │   • central-collector │  │
│  └─────────────────────┘  │                  │  └───────────────────────┘  │
└───────────────────────────┘                  └─────────────────────────────┘
            │                                                  │
            ▼                                                  ▼
┌───────────────────────────┐                  ┌─────────────────────────────┐
│  OpenShift Console        │                  │  OpenShift Console          │
│                           │                  │                             │
│  Observe → Traces         │                  │  Observe → Metrics          │
│  (Distributed Tracing UI) │                  │  (Monitoring UI + Perses)   │
└───────────────────────────┘                  └─────────────────────────────┘
EOF

wait
clear

explain "Step 1: Deploy RBAC for OpenTelemetry collectors"
pei "oc apply -f manifests/4-opentelemetry/rbac.yaml"
pei "oc apply -f manifests/4-opentelemetry/tempo-writer-rbac.yaml"

wait
clear

explain "Step 2: Deploy auto-instrumentation configuration"
echo "This defines how to instrument each language (Python, Node.js, Java, Go)"
echo ""
show_yaml "manifests/4-opentelemetry/instrumentation.yaml" "📄 Instrumentation - Auto-inject agents for each language"

pei "oc apply -f manifests/4-opentelemetry/instrumentation.yaml"

echo ""
pei "oc get instrumentation -n observability-demo"

wait
clear

explain "Step 3: Deploy sidecar collector"
echo "Runs alongside each app pod, receives OTLP from the app"
pei "oc apply -f manifests/4-opentelemetry/sidecar-collector.yaml"

wait
clear

explain "Step 4: Deploy central collector"
echo "Aggregates telemetry, generates RED metrics, exports to Tempo/Prometheus"
echo ""
show_yaml "manifests/4-opentelemetry/central-collector.yaml" "📄 Central Collector - Notice the spanmetrics connector for RED metrics!"

pei "oc apply -f manifests/4-opentelemetry/central-collector.yaml"

echo ""
explain "Waiting for central collector to be ready..."
sleep 5
pei "oc wait --for=condition=Ready pods -l app.kubernetes.io/component=opentelemetry-collector -n observability-demo --timeout=120s || echo 'Note: Collector pods may take a moment to appear'"

wait
clear

explain "Step 5: Enable auto-instrumentation via annotations"
echo "⚡ This is the ONLY change to the deployments!"
echo ""
echo "Adding to each deployment:"
echo "  1. Service account: otel-collector-sidecar"
echo "  2. Annotation: sidecar.opentelemetry.io/inject: sidecar"
echo "  3. Annotation: instrumentation.opentelemetry.io/inject-<lang>: demo-instrumentation"

wait

explain "Patching go-api deployment..."
pei "oc patch deployment go-api -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

explain "Patching python-api deployment..."
pei "oc patch deployment python-api -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\",\"instrumentation.opentelemetry.io/inject-python\":\"demo-instrumentation\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

explain "Patching quarkus-api deployment..."
pei "oc patch deployment quarkus-api -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\",\"instrumentation.opentelemetry.io/inject-java\":\"demo-instrumentation\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

explain "Patching node-app deployment..."
pei "oc patch deployment node-app -n observability-demo -p '{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"sidecar.opentelemetry.io/inject\":\"sidecar\",\"instrumentation.opentelemetry.io/inject-nodejs\":\"demo-instrumentation\"}},\"spec\":{\"serviceAccountName\":\"otel-collector-sidecar\"}}}}'"

echo ""
explain "Waiting for demo app pods to restart with instrumentation..."
sleep 10
pei "oc wait --for=condition=Ready pods -l demo=observability -n observability-demo --timeout=120s"

wait
clear

explain "Verifying instrumentation..."
echo "Each pod should now have 2 containers: app + sidecar (otc-container)"
pei "oc get pods -l demo=observability -n observability-demo"

echo ""
echo "Checking OTEL environment variables in python-api:"
pei "oc exec -n observability-demo deployment/python-api -c python-api -- env | grep OTEL_ | head -5"

wait
clear

# ==========================================
# PHASE 4: VISUALIZE & QUERY
# ==========================================

step "Phase 4: Visualize & Query"

explain "Let's understand the request flow with instrumentation:"
p ""
cat << 'EOF' | less -R
User Request
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Node.js App Pod                                                 │
│                                                                 │
│  HTTP Request                                                   │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ Auto-Instrumentation (init container)  │                     │
│  │ • Injects OpenTelemetry SDK            │                     │
│  │ • Sets OTEL_* env vars                 │                     │
│  │ • Configures OTLP endpoint             │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ Express.js App (instrumented)          │                     │
│  │ • Automatic span creation              │                     │
│  │ • Context propagation (W3C)            │                     │
│  │ • Trace ID in logs                     │                     │
│  └────────────────────────────────────────┘                     │
│       ↓ (OTLP to localhost:4318)                                │
│  ┌────────────────────────────────────────┐                     │
│  │ Sidecar Collector                      │                     │
│  │ • Receives OTLP                        │                     │
│  │ • Adds K8s metadata                    │                     │
│  │ • Forwards to central                  │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
└───────┼─────────────────────────────────────────────────────────┘
        │
        │ (calls Python API)
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ Python API Pod                                                  │
│                                                                 │
│  HTTP Request (with trace context in headers)                   │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ Auto-Instrumentation                   │                     │
│  │ • Python OpenTelemetry agent           │                     │
│  │ • Extracts parent trace context        │                     │
│  │ • Creates child span                   │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ FastAPI App (instrumented)             │                     │
│  │ • GET /api/seed                        │                     │
│  │ • Random delay (0.1s - 5s)             │                     │
│  │ • Returns seed value                   │                     │
│  └────────────────────────────────────────┘                     │
│       ↓ (OTLP to localhost:4318)                                │
│  ┌────────────────────────────────────────┐                     │
│  │ Sidecar Collector                      │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
└───────┼─────────────────────────────────────────────────────────┘
        │
        ▼
    [Central Collector → Tempo/Prometheus]
    
    Complete Distributed Trace:
    └─ node-app: GET /api/seed (proxy)
       └─ python-api: GET /api/seed
          ├─ duration: 2.3s
          ├─ span attributes: http.method, http.status_code, k8s.pod.name
          └─ exemplar linked to metric: traces_spanmetrics_latency
EOF

wait
clear

explain "Let's look at the Perses dashboard configuration..."
show_yaml "manifests/5-coo-setup/working-dashboard.yaml" "📄 Perses Dashboard - Notice the panels for RED metrics and application metrics"

explain "Deploying Perses datasource and dashboard..."
pei "oc apply -f manifests/5-coo-setup/perses-datasource.yaml"
pei "oc apply -f manifests/5-coo-setup/working-dashboard.yaml"

wait
clear

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
open "http://localhost:9090"

wait

# Kill port-forward
kill $PF_PID 2>/dev/null || true
clear

explain "Opening OpenShift Console..."
CONSOLE=$(oc whoami --show-console)
echo -e "${GREEN}OpenShift Console: $CONSOLE${NC}"
echo ""
echo "Navigate to:"
echo "  • Observe → Metrics (Perses dashboard)"
echo "  • Observe → Traces (Distributed Tracing UI)"
p ""
open "$CONSOLE/observe/traces"
clear
wait

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
