#!/bin/bash
# Demo Cleanup Script
# This script deletes resources that will be created during the demo
# Run this BEFORE the demo to ensure a clean slate

set -e

echo "========================================="
echo "Observability Demo - Cleanup"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}This script will DELETE:${NC}"
echo "  1. All applications (go-api, python-api, quarkus-api, node-app)"
echo "  2. ServiceMonitors"
echo "  3. OpenTelemetry Collectors (central and sidecar)"
echo "  4. Auto-instrumentation configuration"
echo "  5. RBAC for collectors"
echo "  6. Perses datasource and dashboard"
echo ""
echo -e "${RED}WARNING: This will remove resources needed for the demo!${NC}"
echo "Only run this if you want to start fresh or before running the demo."
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "========================================="
echo "Cleaning up demo resources..."
echo "========================================="
echo ""

# Delete Perses dashboard and datasource
echo "Deleting Perses dashboard and datasource..."
oc delete persesdashboard observability-demo-overview -n openshift-cluster-observability-operator --ignore-not-found=true
oc delete persesdatasource observability-demo-prometheus -n openshift-cluster-observability-operator --ignore-not-found=true

# Delete ServiceMonitors
echo "Deleting ServiceMonitors..."
oc delete servicemonitor --all -n observability-demo --ignore-not-found=true

# Delete OpenTelemetry resources
echo "Deleting OpenTelemetry collectors..."
oc delete opentelemetrycollector central -n observability-demo --ignore-not-found=true
oc delete opentelemetrycollector sidecar -n observability-demo --ignore-not-found=true

echo "Deleting auto-instrumentation configuration..."
oc delete instrumentation demo-instrumentation -n observability-demo --ignore-not-found=true

echo "Deleting RBAC..."
oc delete -f manifests/4-opentelemetry/rbac.yaml --ignore-not-found=true
oc delete -f manifests/4-opentelemetry/tempo-writer-rbac.yaml --ignore-not-found=true

# Delete applications
echo "Deleting applications..."
oc delete deployment go-api -n observability-demo --ignore-not-found=true
oc delete deployment python-api -n observability-demo --ignore-not-found=true
oc delete deployment quarkus-api -n observability-demo --ignore-not-found=true
oc delete deployment node-app -n observability-demo --ignore-not-found=true

oc delete service go-api -n observability-demo --ignore-not-found=true
oc delete service python-api -n observability-demo --ignore-not-found=true
oc delete service quarkus-api -n observability-demo --ignore-not-found=true
oc delete service node-app -n observability-demo --ignore-not-found=true

oc delete route node-app -n observability-demo --ignore-not-found=true

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""
echo "The following are still in place (pre-demo infrastructure):"
echo "  ✓ Operators (COO, Tempo, OpenTelemetry)"
echo "  ✓ MonitoringStack"
echo "  ✓ TempoStack"
echo "  ✓ UI Plugins"
echo "  ✓ observability-demo namespace"
echo ""
echo "Ready for demo! Run: ./demo.sh"
echo ""
