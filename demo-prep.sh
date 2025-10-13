#!/bin/bash
# Demo Preparation Script
# This script sets up the base infrastructure that should be ready before the demo
# Run this BEFORE the demo session

set -e

echo "========================================="
echo "Observability Demo - Pre-Demo Setup"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}This script will install:${NC}"
echo "  1. Cluster Observability Operator"
echo "  2. Tempo Operator"  
echo "  3. OpenTelemetry Operator"
echo "  4. MonitoringStack (Prometheus + Thanos)"
echo "  5. TempoStack (Tempo)"
echo "  6. OpenShift Console UI Plugins"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "========================================="
echo "Step 1: Install Operators"
echo "========================================="

# Cluster Observability Operator
echo -e "${GREEN}Installing Cluster Observability Operator...${NC}"
oc apply -f manifests/2-observability-stack/coo-namespace.yaml
oc apply -f manifests/2-observability-stack/coo-operatorgroup.yaml
oc apply -f manifests/2-observability-stack/coo-subscription.yaml

# Tempo Operator
echo -e "${GREEN}Installing Tempo Operator...${NC}"
oc apply -f manifests/2-observability-stack/tempo-namespace.yaml
oc apply -f manifests/2-observability-stack/tempo-operatorgroup.yaml
oc apply -f manifests/2-observability-stack/tempo-subscription.yaml

# OpenTelemetry Operator
echo -e "${GREEN}Installing OpenTelemetry Operator...${NC}"
oc apply -f manifests/4-opentelemetry/subscription.yaml

echo ""
echo "Waiting for operators to be ready (this may take 2-3 minutes)..."
echo ""

# Wait for Cluster Observability Operator
echo -e "${GREEN}Waiting for Cluster Observability Operator...${NC}"
oc wait --for=condition=Available csv -n openshift-cluster-observability-operator \
  --selector=operators.coreos.com/cluster-observability-operator.openshift-cluster-observability-operator \
  --timeout=300s 2>/dev/null || echo "Timeout waiting for COO, continuing..."

# Wait for Tempo Operator  
echo -e "${GREEN}Waiting for Tempo Operator...${NC}"
oc wait --for=condition=Available csv -n openshift-tempo-operator \
  --selector=operators.coreos.com/tempo-operator.openshift-tempo-operator \
  --timeout=300s 2>/dev/null || echo "Timeout waiting for Tempo, continuing..."

# Wait for OpenTelemetry Operator
echo -e "${GREEN}Waiting for OpenTelemetry Operator...${NC}"
oc wait --for=condition=Available csv -n openshift-operators \
  --selector=operators.coreos.com/opentelemetry-operator.openshift-operators \
  --timeout=300s 2>/dev/null || echo "Timeout waiting for OTel, continuing..."

echo ""
echo "========================================="
echo "Step 2: Deploy Observability Stacks"
echo "========================================="

# Create observability-demo namespace
echo -e "${GREEN}Creating observability-demo namespace...${NC}"
oc apply -f manifests/1-apps/namespace.yaml

# Deploy MonitoringStack
echo -e "${GREEN}Deploying MonitoringStack (Prometheus + Thanos)...${NC}"
oc apply -f manifests/2-observability-stack/coo-monitoring-stack.yaml

# Deploy TempoStack
echo -e "${GREEN}Deploying TempoStack prerequisites...${NC}"
oc apply -f manifests/2-observability-stack/tempo-secret.yaml
oc apply -f manifests/2-observability-stack/tempo-rbac.yaml

echo -e "${GREEN}Deploying TempoStack...${NC}"
oc apply -f manifests/2-observability-stack/tempostack.yaml

echo ""
echo "Waiting for stacks to be ready (this may take 2-3 minutes)..."
echo ""

# Wait for MonitoringStack
echo -e "${GREEN}Waiting for MonitoringStack...${NC}"
oc wait --for=condition=Available monitoringstack/observability-stack \
  -n observability-demo --timeout=300s 2>/dev/null || echo "Timeout waiting for MonitoringStack, continuing..."

# Wait for TempoStack
echo -e "${GREEN}Waiting for TempoStack...${NC}"
oc wait --for=condition=Ready tempostack/tempo \
  -n openshift-tempo-operator --timeout=300s 2>/dev/null || echo "Timeout waiting for TempoStack, continuing..."

echo ""
echo "========================================="
echo "Step 3: Enable UI Plugins"
echo "========================================="

# Enable monitoring UI plugin
echo -e "${GREEN}Enabling monitoring UI plugin...${NC}"
oc apply -f manifests/5-coo-setup/uiplugin-monitoring.yaml

# Enable distributed tracing UI plugin
echo -e "${GREEN}Enabling distributed tracing UI plugin...${NC}"
oc apply -f manifests/5-coo-setup/uiplugin-distributed-tracing.yaml

echo ""
echo "========================================="
echo "Prep Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}✅ All operators installed${NC}"
echo -e "${GREEN}✅ MonitoringStack deployed${NC}"
echo -e "${GREEN}✅ TempoStack deployed${NC}"
echo -e "${GREEN}✅ UI plugins enabled${NC}"
echo ""
echo "The cluster is ready for the demo!"
echo ""
echo "Next steps:"
echo "  1. Review the demo script: ./demo.sh"
echo "  2. Open OpenShift Console: $(oc whoami --show-console)"
echo "  3. Verify stacks are running:"
echo "     - oc get monitoringstack -n observability-demo"
echo "     - oc get tempostack -n openshift-tempo-operator"
echo ""
