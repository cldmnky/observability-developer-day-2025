#!/bin/bash
# Build script for multi-arch container images
# Supports aarch64 (arm64) and amd64 architectures

set -e

REGISTRY="quay.io/cldmnk"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to build and push an image
build_and_push() {
    local service=$1
    local containerfile=$2
    local image_name="${REGISTRY}/${service}:latest"
    
    echo -e "${GREEN}Building multi-arch image for ${service}...${NC}"
    echo -e "${YELLOW}Image: ${image_name}${NC}"
    echo -e "${YELLOW}Platforms: ${PLATFORMS}${NC}"
    
    podman build \
        --platform="${PLATFORMS}" \
        --manifest="${image_name}" \
        -f "${containerfile}" \
        .
    
    echo -e "${GREEN}Pushing ${image_name}...${NC}"
    podman manifest push "${image_name}"
    
    echo -e "${GREEN}✓ Successfully built and pushed ${service}${NC}"
    echo ""
}

# Main script
main() {
    echo -e "${GREEN}Building multi-arch container images...${NC}"
    echo ""
    
    # Check if podman is available
    if ! command -v podman &> /dev/null; then
        echo -e "${RED}Error: podman is not installed${NC}"
        exit 1
    fi
    
    # Build each service
    case "${1:-all}" in
        go)
            build_and_push "observability-go-api" "Containerfile.go-app"
            ;;
        node)
            build_and_push "observability-node-app" "Containerfile.node-app"
            ;;
        quarkus)
            build_and_push "observability-quarkus-api" "Containerfile.quarkus-app"
            ;;
        python)
            build_and_push "observability-python-api" "Containerfile.python-app"
            ;;
        all)
            build_and_push "observability-go-api" "Containerfile.go-app"
            build_and_push "observability-python-api" "Containerfile.python-app"
            build_and_push "observability-node-app" "Containerfile.node-app"
            build_and_push "observability-quarkus-api" "Containerfile.quarkus-app"
            ;;
        *)
            echo -e "${RED}Usage: $0 [go|node|quarkus|python|all]${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}All builds completed successfully!${NC}"
}

main "$@"
