#!/bin/bash
# OCaml Devcontainer Multi-Architecture Builder
# Handles Docker buildx setup and multi-architecture builds for OCaml development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUILDER_NAME="oxcaml-multiarch"
IMAGE_NAME="${IMAGE_NAME:-oxcaml-icfp-tutorial}"
TAG="${TAG:-latest}"
DOCKERFILE_PATH=".devcontainer/dockerfile"

# Usage function
show_usage() {
    echo -e "${GREEN}OCaml Devcontainer Multi-Architecture Builder${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC} $0 <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  setup       - Setup Docker buildx for multi-architecture builds"
    echo "  build       - Build for current platform (can run locally)"
    echo "  build-multi - Build for multiple architectures (amd64 + arm64)"
    echo "  push        - Build and push multi-architecture image to registry"
    echo "  run         - Run the built container interactively"
    echo "  clean       - Remove built images and builder"
    echo "  inspect     - Show buildx builder capabilities"
    echo "  help        - Show this help message"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "  IMAGE_NAME  - Docker image name (default: oxcaml-icfp-tutorial)"
    echo "  TAG         - Docker image tag (default: latest)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 setup                    - One-time setup"
    echo "  $0 build                    - Build for local development"
    echo "  $0 build-multi              - Build multi-arch for registry"
    echo "  TAG=v1.0 $0 push           - Build and push with custom tag"
}

# Setup buildx builder
setup_buildx() {
    echo -e "${GREEN}Setting up Docker buildx for multi-architecture builds...${NC}"

    if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
        echo -e "${YELLOW}Creating new buildx builder: $BUILDER_NAME${NC}"
        docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
    else
        echo -e "${GREEN}Builder $BUILDER_NAME already exists${NC}"
    fi

    echo -e "${YELLOW}Using builder: $BUILDER_NAME${NC}"
    docker buildx use "$BUILDER_NAME"

    echo -e "${GREEN}✓ Buildx setup complete${NC}"
}

# Build for current platform
build_local() {
    setup_buildx

    CURRENT_PLATFORM="linux/$(uname -m | sed 's/x86_64/amd64/')"
    echo -e "${GREEN}Building for current platform: $CURRENT_PLATFORM${NC}"

    docker buildx build \
        --platform "$CURRENT_PLATFORM" \
        --tag "$IMAGE_NAME:$TAG" \
        --file "$DOCKERFILE_PATH" \
        --load \
        .

    echo -e "${GREEN}✓ Local build complete: $IMAGE_NAME:$TAG${NC}"
}

# Build for multiple architectures
build_multiarch() {
    setup_buildx

    echo -e "${GREEN}Building for multiple architectures: linux/amd64, linux/arm64${NC}"

    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag "$IMAGE_NAME:$TAG" \
        --file "$DOCKERFILE_PATH" \
        --output type=image,push=false \
        .

    echo -e "${GREEN}✓ Multi-architecture build complete${NC}"
    echo -e "${YELLOW}Note: Multi-arch images are stored in buildx cache. Use 'push' to deploy to registry.${NC}"
}

# Build and push to registry
push_multiarch() {
    setup_buildx

    echo -e "${GREEN}Building and pushing multi-architecture image to registry...${NC}"

    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag "$IMAGE_NAME:$TAG" \
        --file "$DOCKERFILE_PATH" \
        --push \
        .

    echo -e "${GREEN}✓ Multi-architecture image pushed to registry: $IMAGE_NAME:$TAG${NC}"
}

# Run the container
run_container() {
    echo -e "${GREEN}Running container: $IMAGE_NAME:$TAG${NC}"

    if ! docker images | grep -q "$IMAGE_NAME.*$TAG"; then
        echo -e "${YELLOW}Image not found locally. Building first...${NC}"
        build_local
    fi

    docker run -it --rm \
        -v "$(pwd)":/workspace \
        -w /workspace \
        "$IMAGE_NAME:$TAG" \
        bash
}

# Clean up
cleanup() {
    echo -e "${GREEN}Cleaning up images and builder...${NC}"

    # Remove images
    docker rmi "$IMAGE_NAME:$TAG" 2>/dev/null || echo -e "${YELLOW}Image $IMAGE_NAME:$TAG not found${NC}"

    # Remove builder
    if docker buildx ls | grep -q "$BUILDER_NAME"; then
        docker buildx rm "$BUILDER_NAME"
        echo -e "${GREEN}✓ Builder $BUILDER_NAME removed${NC}"
    fi

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Inspect builder
inspect_builder() {
    if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
        setup_buildx
    else
        docker buildx use "$BUILDER_NAME"
    fi

    echo -e "${GREEN}Inspecting builder capabilities...${NC}"
    docker buildx inspect --bootstrap
}

# Main command processing
case "${1:-help}" in
    setup)
        setup_buildx
        ;;
    build)
        build_local
        ;;
    build-multi)
        build_multiarch
        ;;
    push)
        push_multiarch
        ;;
    run)
        run_container
        ;;
    clean)
        cleanup
        ;;
    inspect)
        inspect_builder
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac