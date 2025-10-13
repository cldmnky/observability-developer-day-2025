#!/bin/bash
# Observability Stack Verification Script

set -e

echo "=================================================="
echo "  Observability Stack Verification"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# 1. Check Applications
echo "1. Checking Applications (observability-demo namespace)..."
echo "   ----------------------------------------"
oc get pods -n observability-demo --no-headers | grep -E "go-api|python-api|quarkus-api|node-app" | while read line; do
    name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $3}')
    if [ "$status" == "Running" ]; then
        echo -e "   ${GREEN}✓${NC} $name"
    else
        echo -e "   ${RED}✗${NC} $name ($status)"
    fi
done
echo ""

# 2. Check Services
echo "2. Checking Services..."
echo "   ----------------------------------------"
for svc in go-api python-api quarkus-api node-app; do
    if oc get svc $svc -n observability-demo &>/dev/null; then
        check_status "   $svc service exists"
    fi
done
echo ""

# 3. Check Route
echo "3. Checking OpenShift Route..."
echo "   ----------------------------------------"
if oc get route node-app -n observability-demo &>/dev/null; then
    ROUTE_URL=$(oc get route node-app -n observability-demo -o jsonpath='{.spec.host}')
    echo -e "   ${GREEN}✓${NC} node-app route: https://$ROUTE_URL"
fi
echo ""

# 4. Check Monitoring Stack
echo "4. Checking Monitoring Stack..."
echo "   ----------------------------------------"
if oc get monitoringstack observability-stack -n observability-demo &>/dev/null; then
    check_status "   MonitoringStack exists"
    STATUS=$(oc get monitoringstack observability-stack -n observability-demo -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    if [ "$STATUS" == "True" ]; then
        echo -e "   ${GREEN}✓${NC} MonitoringStack is Available"
    else
        echo -e "   ${YELLOW}⚠${NC} MonitoringStack status: $STATUS"
    fi
fi

if oc get thanosquerier observability-stack -n observability-demo &>/dev/null; then
    check_status "   ThanosQuerier exists"
fi
echo ""

# 5. Check Monitoring Pods
echo "5. Checking Monitoring Pods..."
echo "   ----------------------------------------"
oc get pods -n observability-demo --no-headers | grep -E "prometheus|alertmanager|thanos" | while read line; do
    name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $3}')
    if [ "$status" == "Running" ]; then
        echo -e "   ${GREEN}✓${NC} $name"
    elif [ "$status" == "Pending" ] && [[ $name == *"alertmanager-1"* ]]; then
        echo -e "   ${YELLOW}⚠${NC} $name (expected on single-node cluster)"
    else
        echo -e "   ${RED}✗${NC} $name ($status)"
    fi
done
echo ""

# 6. Check ServiceMonitors
echo "6. Checking ServiceMonitors..."
echo "   ----------------------------------------"
SM_COUNT=$(oc get servicemonitors -n observability-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "   Found $SM_COUNT ServiceMonitors"
for sm in go-api python-api quarkus-api node-app; do
    if oc get servicemonitor $sm -n observability-demo &>/dev/null; then
        LABEL=$(oc get servicemonitor $sm -n observability-demo -o jsonpath='{.metadata.labels.monitoring\.rhobs/stack}')
        if [ "$LABEL" == "observability-stack" ]; then
            echo -e "   ${GREEN}✓${NC} $sm (label: monitoring.rhobs/stack=observability-stack)"
        else
            echo -e "   ${YELLOW}⚠${NC} $sm (missing label)"
        fi
    fi
done
echo ""

# 7. Check Tempo Stack
echo "7. Checking Tempo Stack (openshift-tempo-operator)..."
echo "   ----------------------------------------"
if oc get tempostack tempo -n openshift-tempo-operator &>/dev/null; then
    check_status "   TempoStack exists"
    
    # Check Tempo pods
    TEMPO_PODS=$(oc get pods -n openshift-tempo-operator --no-headers 2>/dev/null | grep -c "tempo-tempo" || true)
    if [ "$TEMPO_PODS" -gt 0 ]; then
        echo -e "   ${GREEN}✓${NC} Tempo pods: $TEMPO_PODS running"
    fi
    
    # Show OTLP endpoints
    echo "   OTLP endpoints:"
    echo "     - HTTP: tempo-tempo-distributor.openshift-tempo-operator.svc:4318"
    echo "     - gRPC: tempo-tempo-distributor.openshift-tempo-operator.svc:4317"
fi
echo ""

# 8. Test Metrics Endpoints
echo "8. Testing Metrics Endpoints..."
echo "   ----------------------------------------"
for app in go-api python-api quarkus-api node-app; do
    POD=$(oc get pod -n observability-demo -l app=$app -o name 2>/dev/null | head -1)
    if [ -n "$POD" ]; then
        PORT=$(oc get svc $app -n observability-demo -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
        if oc exec -n observability-demo $POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/metrics 2>/dev/null | grep -q "200"; then
            echo -e "   ${GREEN}✓${NC} $app /metrics endpoint responds"
        else
            echo -e "   ${RED}✗${NC} $app /metrics endpoint not accessible"
        fi
    fi
done
echo ""

# 9. Summary
echo "=================================================="
echo "  Summary"
echo "=================================================="
echo ""
echo "Access Points:"
echo "  • Prometheus UI:"
echo "    oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090"
echo "    http://localhost:9090"
echo ""
echo "  • Thanos Querier UI:"
echo "    oc port-forward -n observability-demo svc/thanos-querier-observability-stack 9090:9090"
echo "    http://localhost:9090"
echo ""
echo "  • Jaeger UI (Tempo):"
echo "    oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686"
echo "    http://localhost:16686"
echo ""
if [ -n "$ROUTE_URL" ]; then
    echo "  • Application UI:"
    echo "    https://$ROUTE_URL"
    echo ""
fi
echo "Documentation:"
echo "  • Complete Guide: manifests/OBSERVABILITY_GUIDE.md"
echo "  • Deployment Summary: manifests/DEPLOYMENT_SUMMARY.md"
echo ""
echo "=================================================="
