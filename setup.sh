#!/usr/bin/env bash
set -euo pipefail

PPA_URL="https://antux912012.github.io/arda-tech-ppa"
KEYRING_PATH="/etc/apt/keyrings/arda-tech.gpg"
LIST_PATH="/etc/apt/sources.list.d/arda-tech.list"

if [ "$(id -u)" -ne 0 ]; then
  echo "Elevating privileges with sudo..."
  exec sudo bash "$0" "$@"
fi

echo "==> [1/3] Installing Arda-Tech PPA GPG signing key (${KEYRING_PATH})..."
mkdir -p /etc/apt/keyrings
curl -fsSL "${PPA_URL}/KEY.gpg" -o "${KEYRING_PATH}"
chmod 644 "${KEYRING_PATH}"

echo "==> [2/3] Configuring APT repository source (${LIST_PATH})..."
echo "deb [signed-by=${KEYRING_PATH}] ${PPA_URL} stable main" > "${LIST_PATH}"
chmod 644 "${LIST_PATH}"

echo "==> [3/3] Updating APT package index..."
apt-get update

cat << 'EOF'

======================================================================
  ✨ Arda-Tech PPA configured successfully!
======================================================================
Install any Arda-Tech application with apt:

  sudo apt install mithrandir                  # System Cleaner & AI Diagnostics (Python/GTK4)
  sudo apt install mithrandir-rs               # System Cleaner & Optimizer (Rust/GTK4)
  sudo apt install vingilot                    # Privacy-First Wayland Browser (WebKitGTK 6.0)
  sudo apt install vingilot-estel              # Next-Gen Browser (Servo & WebKit Hybrid)
  sudo apt install imladris                    # Native Markdown & Polyglot Studio (GTK4)
  sudo apt install cachy-kernel-updater        # Debian CachyOS BORE Kernel Forger & Updater
  sudo apt install yt-comment-extractor        # YouTube Comment Extractor GUI (GTK4)
  sudo apt install yt-comment-extractor-service # YouTube Comment Extractor Web Daemon & Tray
  sudo apt install sulimo                      # Arda's Breath Hardware Capability Probe CLI
  sudo apt install vfs5011-linux-fix           # Validity VFS5011 Fingerprint Sensor Driver Fix
======================================================================
EOF
