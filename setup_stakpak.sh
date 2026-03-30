#!/bin/bash
set -euo pipefail

# --- Configuration ---
REPO_URL="https://github.com/suryansh639/agent.git"
CLONE_DIR="agent"
# Assuming a standard x86_64 Linux server, matching the robust Docker build target
TARGET_ARCH="x86_64-unknown-linux-musl"
# Based on AGENTS.md "nightly features enabled" and rust-toolchain.toml
RUST_TOOLCHAIN="nightly"

echo "Starting Stakpak project setup on Linux server."

# 1. Update system and install essential build dependencies
echo "Updating system and installing build dependencies (requires sudo)..."
# Common packages: git for cloning, curl for rustup, build-essential for C toolchain,
# pkg-config and libssl-dev for Rust's OpenSSL dependency.
# clang: often needed by Rust projects.
# musl-tools: required for building with the musl target.
sudo yum update -y
sudo yum groupinstall -y 'Development Tools'
sudo yum install -y git curl openssl-devel clang llvm musl-devel

# 2. Clone the repository
if [ -d "$CLONE_DIR" ]; then
    echo "Directory '$CLONE_DIR' already exists. Skipping clone."
    # Optional: Uncomment the following lines if you want to update the existing repository
    # echo "Updating existing repository..."
    # pushd "$CLONE_DIR"
    # git pull --ff-only
    # popd
else
    echo "Cloning '$REPO_URL' into '$CLONE_DIR'..."
    git clone "$REPO_URL" "$CLONE_DIR"
fi

# 3. Install Rust using rustup, specifically the nightly toolchain and the musl target
echo "Installing Rust toolchain ('$RUST_TOOLCHAIN') and target ('$TARGET_ARCH') via rustup..."
# Check if rustup is already installed
if ! command -v rustup &> /dev/null
then
    echo "Rustup not found. Installing now."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # Ensure cargo is in PATH for the current shell session
    source "$HOME/.cargo/env"
else
    echo "Rustup is already installed. Updating toolchain and adding target."
    # Ensure env vars are loaded in case the script is run in a non-login shell
    source "$HOME/.cargo/env"
    rustup update "$RUST_TOOLCHAIN" --no-self-update # Update specific toolchain, avoid updating rustup itself
fi

# Install the specific toolchain and target, and set it as default
rustup install "$RUST_TOOLCHAIN"
rustup default "$RUST_TOOLCHAIN"
rustup target add "$TARGET_ARCH" --toolchain "$RUST_TOOLCHAIN"

# 4. Navigate to the project directory
echo "Navigating to project directory: $CLONE_DIR"
cd "$CLONE_DIR"

# 5. Build the Stakpak project in release mode for the specified target
# `--workspace`: builds all crates in the workspace
# `--bin stakpak`: specifically builds the 'stakpak' binary
# `--features jemalloc`: enables the jemalloc allocator for improved memory management on Linux
echo "Building Stakpak project for release ($TARGET_ARCH) with jemalloc feature..."
cargo build --release --target "$TARGET_ARCH" --workspace --bin stakpak --features jemalloc

# 6. Verify the build and provide instructions
BUILT_BINARY_PATH="target/$TARGET_ARCH/release/stakpak"
if [ -f "$BUILT_BINARY_PATH" ]; then
    echo "
-----------------------------------------------------"
    echo "Stakpak build successful!"
    echo "Executable is located at: $(pwd)/$BUILT_BINARY_PATH"
    echo "-----------------------------------------------------
"

    echo "To run Stakpak and see its basic help documentation:"
    echo "  ./$BUILT_BINARY_PATH --help"
    echo ""
    echo "To run Stakpak in interactive mode with a prompt (e.g., asking a question):"
    echo "  ./$BUILT_BINARY_PATH "What are the main components of a CI/CD pipeline?""
    echo ""
    echo "To install and run Stakpak as a persistent Autopilot service:"
    echo "  ./$BUILT_BINARY_PATH autopilot up"
    echo "  (Note: Autopilot requires further configuration like API keys and schedules after initial setup."
    echo "   Refer to the project's AGENTS.md for more details on Autopilot setup.)"
else
    echo "
-----------------------------------------------------"
    echo "ERROR: Stakpak executable not found after build!"
    echo "Expected path: $(pwd)/$BUILT_BINARY_PATH"
    echo "Please review the build output for any errors or missing dependencies."
    echo "-----------------------------------------------------
"
    exit 1
fi

echo "Stakpak setup and build script completed."
echo "Remember to configure your Stakpak API key or LLM provider credentials for full functionality."
