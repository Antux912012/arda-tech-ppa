#!/usr/bin/env bash
set -euo pipefail

PPA_DIR="/home/antonio/arda-tech-ppa"
ARDA_TECH_DIR="/home/antonio/arda-tech"
KEY_ID="4C4C7DAF16CE97060FAF10AECF9DC18F75B6C72B"

mkdir -p "$PPA_DIR/scripts"
cd "$PPA_DIR"

echo "==> 1. Cleaning and preparing APT pool & dists directories..."
rm -rf pool dists
mkdir -p \
  pool/main/m/mithrandir \
  pool/main/m/mithrandir-rs \
  pool/main/v/vingilot \
  pool/main/v/vingilot-estel \
  pool/main/i/imladris \
  pool/main/c/cachy-kernel-updater \
  pool/main/y/yt-comment-extractor \
  pool/main/y/yt-comment-extractor-service \
  pool/main/s/sulimo \
  pool/main/v/vfs5011-linux-fix \
  dists/stable/main/binary-amd64 \
  dists/stable/main/binary-all

find_latest_deb() {
  local search_dir="$1"
  local pkg_name="$2"
  local best_deb=""
  local best_ver=""

  while IFS= read -r -d '' deb; do
    local p ver
    p=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
    ver=$(dpkg-deb -f "$deb" Version 2>/dev/null || true)
    if [ "$p" = "$pkg_name" ] && [ -n "$ver" ]; then
      if [ -z "$best_ver" ] || dpkg --compare-versions "$ver" gt "$best_ver"; then
        best_ver="$ver"
        best_deb="$deb"
      fi
    fi
  done < <(find "$search_dir" -maxdepth 2 \( -type f -o -type l \) -name "${pkg_name}_*.deb" -print0 2>/dev/null)

  if [ -z "$best_deb" ]; then
    echo "ERROR: Could not find any .deb for package '$pkg_name' in '$search_dir'" >&2
    return 1
  fi
  echo "$best_deb"
}

copy_latest_deb() {
  local search_dir="$1"
  local pkg_name="$2"
  local pool_subdir="$3"

  local deb_path ver arch target_name
  deb_path=$(find_latest_deb "$search_dir" "$pkg_name")
  ver=$(dpkg-deb -f "$deb_path" Version)
  arch=$(dpkg-deb -f "$deb_path" Architecture)
  target_name="${pkg_name}_${ver}_${arch}.deb"

  cp -Lf "$deb_path" "${pool_subdir}/${target_name}"
  echo "  -> ${pkg_name} v${ver} (${arch}): ${pool_subdir}/${target_name}"
}

echo "==> 2. Selecting and copying latest .deb packages into pool/main/..."
copy_latest_deb "/home/antonio/Projects/mithrandir" "mithrandir" "pool/main/m/mithrandir"
copy_latest_deb "/home/antonio/Projects/mithrandir-rs" "mithrandir-rs" "pool/main/m/mithrandir-rs"
copy_latest_deb "/home/antonio/Projects/Vingilot/dist" "vingilot" "pool/main/v/vingilot"
copy_latest_deb "/home/antonio/Projects/Vingilot-Estel/dist" "vingilot-estel" "pool/main/v/vingilot-estel"
copy_latest_deb "/home/antonio/Projects/Imladris" "imladris" "pool/main/i/imladris"
copy_latest_deb "/home/antonio/Projects/debian-cachy-kernel-updater/deb_dist" "cachy-kernel-updater" "pool/main/c/cachy-kernel-updater"
copy_latest_deb "/home/antonio/Projects/YT-Comment-Extractor" "yt-comment-extractor" "pool/main/y/yt-comment-extractor"
copy_latest_deb "/home/antonio/Projects/YT-Comment-Extractor" "yt-comment-extractor-service" "pool/main/y/yt-comment-extractor-service"
copy_latest_deb "/home/antonio/Projects/Súlimo" "sulimo" "pool/main/s/sulimo"
copy_latest_deb "/home/antonio/Projects/vfs5011-linux-fix" "vfs5011-linux-fix" "pool/main/v/vfs5011-linux-fix"

echo "==> 3. Generating Packages and Packages.gz indices..."
dpkg-scanpackages --multiversion pool/main /dev/null > dists/stable/main/binary-amd64/Packages
gzip -9c dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz

cp -a dists/stable/main/binary-amd64/Packages dists/stable/main/binary-all/Packages
cp -a dists/stable/main/binary-amd64/Packages.gz dists/stable/main/binary-all/Packages.gz

SUITES=("stable" "bookworm" "trixie" "sid" "noble" "jammy")

for suite in "${SUITES[@]}"; do
  if [ "$suite" != "stable" ]; then
    rm -rf "dists/$suite"
    cp -a dists/stable "dists/$suite"
  fi

  echo "==> 4. Generating and signing Release / InRelease for suite: $suite..."
  pushd "dists/$suite" >/dev/null
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="Arda Tech PPA" \
    -o APT::FTPArchive::Release::Label="Arda Tech Official PPA" \
    -o APT::FTPArchive::Release::Suite="$suite" \
    -o APT::FTPArchive::Release::Codename="$suite" \
    -o APT::FTPArchive::Release::Architectures="amd64 all" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="Official Arda Tech Debian & Ubuntu APT PPA Repository by Antux912012" \
    release . > Release

  gpg --batch --yes --default-key "$KEY_ID" -abs -o Release.gpg Release
  gpg --batch --yes --default-key "$KEY_ID" --clearsign -o InRelease Release
  popd >/dev/null
done

echo "==> 5. Exporting GPG public keys..."
gpg --armor --export "$KEY_ID" > KEY.asc
gpg --export "$KEY_ID" > KEY.gpg
gpg --export "$KEY_ID" > arda-tech.gpg
gpg --export "$KEY_ID" > arda-tech-archive-keyring.gpg
touch .nojekyll

echo "==> 6. Synchronizing metadata (index.html, README.md, apps.json) and arda-tech mirror..."
python3 - "$PPA_DIR" "$ARDA_TECH_DIR" << 'PYEOF'
import json
import os
import re
import shutil
import subprocess
import sys

ppa_dir = sys.argv[1]
arda_dir = sys.argv[2]

pkg_info = {}
for root, _, files in os.walk(os.path.join(ppa_dir, "pool", "main")):
    for f in files:
        if f.endswith(".deb"):
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, ppa_dir)
            pkg = subprocess.check_output(["dpkg-deb", "-f", full_path, "Package"], text=True).strip()
            ver = subprocess.check_output(["dpkg-deb", "-f", full_path, "Version"], text=True).strip()
            arch = subprocess.check_output(["dpkg-deb", "-f", full_path, "Architecture"], text=True).strip()
            pkg_info[pkg] = {"version": ver, "arch": arch, "debUrl": rel_path, "filename": f}

# 1. Update arda-tech-ppa/index.html
ppa_index = os.path.join(ppa_dir, "index.html")
if os.path.exists(ppa_index):
    with open(ppa_index, "r", encoding="utf-8") as fh:
        html = fh.read()
    for pkg, info in pkg_info.items():
        # Match within the same card (no closing </a> before sudo apt install <pkg>)
        pattern = re.compile(
            r'(>v)[^<]+( • ' + re.escape(info["arch"]) + r'</span>(?:(?!</a>).)*?sudo apt install ' + re.escape(pkg) + r'</code>\s*<a href=")pool/main/[^"]+/' + re.escape(pkg) + r'_[^"]+\.deb(")',
            re.DOTALL
        )
        html = pattern.sub(r'\g<1>' + info["version"] + r'\g<2>' + info["debUrl"] + r'\g<3>', html)
    with open(ppa_index, "w", encoding="utf-8") as fh:
        fh.write(html)

# 2. Update arda-tech-ppa/README.md and arda-tech-ppa/apps.json
ppa_readme = os.path.join(ppa_dir, "README.md")
if os.path.exists(ppa_readme):
    with open(ppa_readme, "r", encoding="utf-8") as fh:
        md = fh.read()
    for pkg, info in pkg_info.items():
        md = re.sub(
            r'(\|\s*\*\*`' + re.escape(pkg) + r'`\*\*\s*\|\s*`)[^`]+(`\s*\|)',
            r'\g<1>' + info["version"] + r'\g<2>',
            md
        )
    with open(ppa_readme, "w", encoding="utf-8") as fh:
        fh.write(md)

ppa_apps_json = os.path.join(ppa_dir, "apps.json")
if os.path.exists(ppa_apps_json):
    with open(ppa_apps_json, "r", encoding="utf-8") as fh:
        apps = json.load(fh)
    for app in apps:
        apt_pkg = app.get("aptPackage")
        if apt_pkg in pkg_info:
            app["version"] = pkg_info[apt_pkg]["version"]
            app["debUrl"] = pkg_info[apt_pkg]["debUrl"]
    with open(ppa_apps_json, "w", encoding="utf-8") as fh:
        json.dump(apps, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

# 3. Update arda-tech/apps.json, README.md, pool/, and dists/
if os.path.isdir(arda_dir):
    apps_json_path = os.path.join(arda_dir, "apps.json")
    if os.path.exists(apps_json_path):
        with open(apps_json_path, "r", encoding="utf-8") as fh:
            apps = json.load(fh)
        for app in apps:
            apt_pkg = app.get("aptPackage")
            if apt_pkg in pkg_info:
                app["version"] = pkg_info[apt_pkg]["version"]
                app["debUrl"] = pkg_info[apt_pkg]["debUrl"]
        with open(apps_json_path, "w", encoding="utf-8") as fh:
            json.dump(apps, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    arda_readme = os.path.join(arda_dir, "README.md")
    if os.path.exists(arda_readme):
        with open(arda_readme, "r", encoding="utf-8") as fh:
            md = fh.read()
        for pkg, info in pkg_info.items():
            md = re.sub(
                r'(\|\s*`[^`]*`\s*\|\s*`(?:amd64|all)`\s*\|\s*`sudo apt install ' + re.escape(pkg) + r'`\s*\|)',
                lambda m: re.sub(r'^\|\s*`[^`]*`', f"| `{info['version']}`", m.group(0)),
                md
            )
        with open(arda_readme, "w", encoding="utf-8") as fh:
            fh.write(md)

    for sub in ("pool", "dists"):
        dst = os.path.join(arda_dir, sub)
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(os.path.join(ppa_dir, sub), dst)
PYEOF

echo "==> Arda-Tech PPA built, signed, and synchronized successfully!"
