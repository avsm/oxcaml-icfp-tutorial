# OCaml Devcontainer with Multi-Architecture Support

This directory contains everything needed for OCaml development with Docker multi-architecture support.

## VS Code Dev Containers

### Option 1: Use Pre-built Image from Docker Hub (Recommended)

**Default configuration** - Fast setup, no build required!

1. Open the project in VS Code
2. Press `Cmd/Ctrl + Shift + P`
3. Select "Dev Containers: Reopen in Container"
4. Wait for image to pull from Docker Hub (~5-10 minutes)

**Image**: `kayceesrk/oxcaml-icfp-tutorial:latest`

### Option 2: Build Locally

For development or customization:

1. Open the project in VS Code
2. Press `Cmd/Ctrl + Shift + P`
3. Select "Dev Containers: Open Folder in Container..."
4. Choose `.devcontainer-from-scratch` folder
5. Wait for local build (~30-40 minutes)

## Manual Docker Commands

**One script does everything:**

```bash
# One-time setup
.devcontainer/build.sh setup

# Build for local development
.devcontainer/build.sh build

# Run the container
.devcontainer/build.sh run
```

## All Commands

```bash
.devcontainer/build.sh setup       # Setup Docker buildx
.devcontainer/build.sh build       # Build for current platform (local)
.devcontainer/build.sh build-multi # Build for amd64 + arm64
.devcontainer/build.sh push        # Build and push to registry
.devcontainer/build.sh run         # Run container interactively
.devcontainer/build.sh clean       # Clean up images and builder
.devcontainer/build.sh inspect     # Show buildx capabilities
.devcontainer/build.sh help        # Show help
```

## Environment Variables

```bash
IMAGE_NAME=my-project TAG=v1.0 .devcontainer/build.sh build
```

## Files

- `build.sh` - Single script for all Docker operations
- `dockerfile` - Multi-architecture Dockerfile
- `devcontainer.json` - VS Code devcontainer configuration
- `docker-compose.yml` - Docker Compose setup
- `README.md` - This file

## Multi-Architecture Notes

- **Local development**: Use `build` (current platform, can run locally)
- **Registry deployment**: Use `build-multi` or `push` (builds for both AMD64 + ARM64)
- **Platform testing**: Images support `--platform linux/amd64` and `--platform linux/arm64`
