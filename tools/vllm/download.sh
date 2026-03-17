#!/bin/bash
# Create a working directory
mkdir -p ~/vllm-metal-setup

# make sure it's empty
rm -rf ~/vllm-metal-setup/*

# Create mise toml there and make sure python 3.12 is installed
cp ${BASH_SOURCE[0]}/vllm.mise.toml ~/vllm-metal-setup
cd ~/vllm-metal-setup
mise install # accept
which python -> should be the mise one
 
# Pin to a specific release tag (not main, which changes constantly)
RELEASE_TAG="v0.1.0-20260317-040905"
BASE_URL="https://raw.githubusercontent.com/vllm-project/vllm-metal/${RELEASE_TAG}"
 
# Download both scripts
curl -fsSL "${BASE_URL}/install.sh" -o install.sh
curl -fsSL "${BASE_URL}/scripts/lib.sh" -o lib.sh
 
# Save checksums for your audit trail
shasum -a 256 install.sh lib.sh | tee install-checksums.sha256