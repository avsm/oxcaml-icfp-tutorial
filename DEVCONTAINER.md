# Dev Container Options

This project provides two development container configurations:

## 🚀 Quick Start (Recommended)

**Use the pre-built Docker Hub image:**

1. Open this folder in VS Code
2. Click "Reopen in Container" when prompted
   - OR: `Cmd/Ctrl + Shift + P` → "Dev Containers: Reopen in Container"

**Time**: ~5-10 minutes (download only)
**Config**: `.devcontainer/devcontainer.json`
**Image**: `oxcaml/tutorial-icfp25:latest` (8.88 GB)

## 🔧 Local Build

**Build the container locally from scratch:**

1. Open this folder in VS Code
2. `Cmd/Ctrl + Shift + P` → "Dev Containers: Open Folder in Container..."
3. Select the `.devcontainer-from-scratch` folder
4. Wait for build to complete

**Time**: ~30-40 minutes (full build)
**Config**: `.devcontainer-from-scratch/devcontainer.json`
**Use when**: You need to modify the dockerfile

## What's Included

Both containers include:

- OCaml 5.3 (default switch)
- OCaml 5.3.0+tsan (ThreadSanitizer support)
- OCaml 5.2.0+ox (OxCamL parallel extensions) - **default**
- Development tools: ocaml-lsp-server, odoc, ocamlformat, utop, merlin
- OxCamL packages: parallel, core_unix

## Manual Docker Usage

See [.devcontainer/README.md](.devcontainer/README.md) for manual Docker commands.
