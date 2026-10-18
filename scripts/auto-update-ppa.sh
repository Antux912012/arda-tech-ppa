#!/usr/bin/env bash
set -euo pipefail

export PATH="/home/antonio/.cargo/bin:/home/antonio/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

PPA_DIR="/home/antonio/arda-tech-ppa"
ARDA_TECH_DIR="/home/antonio/arda-tech"
STATE_FILE="${PPA_DIR}/.ppa-state.json"
LOG_DIR="${PPA_DIR}/logs"
LOCK_FILE="/tmp/arda-tech-ppa-updater.lock"

mkdir -p "${LOG_DIR}"

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "[$(date -Iseconds)] Another instance of auto-update-ppa.sh is already running. Exiting."
  exit 0
fi

FORCE_REBUILD=0
SKIP_PUSH=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE_REBUILD=1 ;;
    --no-push) SKIP_PUSH=1 ;;
  esac
done

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

if [ ! -f "${STATE_FILE}" ]; then
  echo "{}" > "${STATE_FILE}"
fi

get_state_val() {
  local key="$1"
  python3 - "$STATE_FILE" "$key" << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1], "r") as f:
        data = json.load(f)
    print(data.get(sys.argv[2], ""))
except Exception:
    print("")
PYEOF
}

set_state_val() {
  local key="$1"
  local val="$2"
  python3 - "$STATE_FILE" "$key" "$val" << 'PYEOF'
import json, sys
path, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, "r") as f:
        data = json.load(f)
except Exception:
    data = {}
data[k] = v
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
}

get_ppa_pkg_version() {
  local pkg_name="$1"
  local deb
  deb=$(find "${PPA_DIR}/pool/main" -type f -name "${pkg_name}_*.deb" 2>/dev/null | head -n 1 || true)
  if [ -n "$deb" ] && [ -f "$deb" ]; then
    dpkg-deb -f "$deb" Version 2>/dev/null || true
  fi
}

find_latest_project_deb_version() {
  local search_dir="$1"
  local pkg_name="$2"
  local best_ver=""
  while IFS= read -r -d '' deb; do
    local p ver
    p=$(dpkg-deb -f "$deb" Package 2>/dev/null || true)
    ver=$(dpkg-deb -f "$deb" Version 2>/dev/null || true)
    if [ "$p" = "$pkg_name" ] && [ -n "$ver" ]; then
      if [ -z "$best_ver" ] || dpkg --compare-versions "$ver" gt "$best_ver"; then
        best_ver="$ver"
      fi
    fi
  done < <(find "$search_dir" -maxdepth 2 \( -type f -o -type l \) -name "${pkg_name}_*.deb" -print0 2>/dev/null)
  echo "$best_ver"
}

get_source_version() {
  local pkg_name="$1"
  local repo_dir="$2"
  case "$pkg_name" in
    mithrandir)
      grep -m1 "version:" "${repo_dir}/meson.build" | sed -E "s/.*'([^']+)'.*/\1/"
      ;;
    mithrandir-rs)
      grep -m1 '^version' "${repo_dir}/Cargo.toml" | sed -E 's/.*"([^"]+)".*/\1/'
      ;;
    vingilot)
      local v
      v=$(grep -m1 '^version' "${repo_dir}/crates/vingilot-ui/Cargo.toml" | sed -E 's/.*"([^"]+)".*/\1/')
      echo "${v}-1"
      ;;
    vingilot-estel)
      local v
      v=$(grep -m1 '^version' "${repo_dir}/Cargo.toml" | sed -E 's/.*"([^"]+)".*/\1/')
      echo "${v}-1"
      ;;
    imladris)
      grep -m1 "version:" "${repo_dir}/meson.build" | sed -E "s/.*'([^']+)'.*/\1/"
      ;;
    cachy-kernel-updater)
      grep -m1 '^APP_VERSION' "${repo_dir}/main.py" | sed -E 's/.*"([^"]+)".*/\1/'
      ;;
    sulimo)
      grep -m1 "project(arda_breath" "${repo_dir}/CMakeLists.txt" | sed -E 's/.*VERSION ([0-9.]+).*/\1/'
      ;;
    yt-comment-extractor)
      if [ -f "${repo_dir}/release.json" ]; then
        grep -m1 '"tag_name"' "${repo_dir}/release.json" | sed -E 's/.*"v?([^"]+)".*/\1/'
      else
        echo "0.2.0"
      fi
      ;;
    vfs5011-linux-fix)
      echo "1.0.0"
      ;;
  esac
}

# Format: pkg_name|repo_dir|deb_search_dir|build_cmd
PROJECTS=(
  "mithrandir|/home/antonio/Projects/mithrandir|/home/antonio/Projects/mithrandir|./packaging/build_deb.sh"
  "mithrandir-rs|/home/antonio/Projects/mithrandir-rs|/home/antonio/Projects/mithrandir-rs|./packaging/build_deb.sh"
  "vingilot|/home/antonio/Projects/Vingilot|/home/antonio/Projects/Vingilot/dist|./scripts/build-deb.sh"
  "vingilot-estel|/home/antonio/Projects/Vingilot-Estel|/home/antonio/Projects/Vingilot-Estel/dist|./scripts/build-deb.sh"
  "imladris|/home/antonio/Projects/Imladris|/home/antonio/Projects/Imladris|./build-packages.sh --deb-only"
  "cachy-kernel-updater|/home/antonio/Projects/debian-cachy-kernel-updater|/home/antonio/Projects/debian-cachy-kernel-updater/deb_dist|./build_deb.sh"
  "yt-comment-extractor|/home/antonio/Projects/YT-Comment-Extractor|/home/antonio/Projects/YT-Comment-Extractor|./build_deb.sh"
  "sulimo|/home/antonio/Projects/Súlimo|/home/antonio/Projects/Súlimo|./packaging/build_deb.sh"
  "vfs5011-linux-fix|/home/antonio/Projects/vfs5011-linux-fix|/home/antonio/Projects/vfs5011-linux-fix|./build_deb.sh"
)

NEED_PPA_REBUILD=0
UPDATED_PACKAGES=()

log "Checking tracked Arda-Tech repositories for updates..."

for entry in "${PROJECTS[@]}"; do
  IFS='|' read -r pkg_name repo_dir deb_dir build_cmd <<< "$entry"

  if [ ! -d "$repo_dir" ]; then
    log "WARNING: Directory $repo_dir not found, skipping $pkg_name"
    continue
  fi

  pushd "$repo_dir" >/dev/null

  # Check Git remote for new commits on main/master
  NEW_REMOTE_COMMITS=0
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git remote get-url origin >/dev/null 2>&1; then
      git fetch origin --quiet 2>/dev/null || log "Warning: git fetch failed for $pkg_name (working offline/cached)"
      branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
      if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        local_sha=$(git rev-parse HEAD)
        remote_sha=$(git rev-parse "origin/${branch}")
        if [ "$local_sha" != "$remote_sha" ]; then
          if git merge-base --is-ancestor "$local_sha" "$remote_sha"; then
            log "[$pkg_name] New upstream commits detected on origin/${branch} (${local_sha:0:7} -> ${remote_sha:0:7}). Pulling..."
            git pull --ff-only origin "$branch" || log "Warning: Fast-forward pull failed for $pkg_name"
            NEW_REMOTE_COMMITS=1
          fi
        fi
      fi
    fi
    current_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  else
    current_sha="no-git"
  fi

  last_recorded_sha=$(get_state_val "${pkg_name}_sha")
  src_ver=$(get_source_version "$pkg_name" "$repo_dir")
  latest_deb_ver=$(find_latest_project_deb_version "$deb_dir" "$pkg_name")
  ppa_ver=$(get_ppa_pkg_version "$pkg_name")

  REBUILD_PKG=0
  if [ "$NEW_REMOTE_COMMITS" -eq 1 ]; then
    REBUILD_PKG=1
    log "[$pkg_name] Triggering .deb build due to new remote commits on main branch."
  elif [ -n "$last_recorded_sha" ] && [ "$current_sha" != "$last_recorded_sha" ]; then
    # Commit changed since last recorded state; check if .deb for src_ver is missing or older
    if [ -z "$latest_deb_ver" ] || dpkg --compare-versions "$src_ver" gt "$latest_deb_ver"; then
      REBUILD_PKG=1
      log "[$pkg_name] Commit changed and source version ($src_ver) > built .deb ($latest_deb_ver). Building .deb..."
    fi
  elif [ -z "$latest_deb_ver" ] || dpkg --compare-versions "$src_ver" gt "$latest_deb_ver"; then
    REBUILD_PKG=1
    log "[$pkg_name] Source version ($src_ver) is newer than built .deb (${latest_deb_ver:-none}). Building .deb..."
  fi

  if [ "$REBUILD_PKG" -eq 1 ]; then
    log "[$pkg_name] Running build command: $build_cmd"
    eval "$build_cmd"
    latest_deb_ver=$(find_latest_project_deb_version "$deb_dir" "$pkg_name")
  fi

  # Also check if SHA256 of latest project .deb differs from PPA .deb
  proj_deb_file=""
  while IFS= read -r -d '' d; do
    p=$(dpkg-deb -f "$d" Package 2>/dev/null || true)
    v=$(dpkg-deb -f "$d" Version 2>/dev/null || true)
    if [ "$p" = "$pkg_name" ] && [ "$v" = "$latest_deb_ver" ]; then
      proj_deb_file="$d"
      break
    fi
  done < <(find "$deb_dir" -maxdepth 2 \( -type f -o -type l \) -name "${pkg_name}_*.deb" -print0 2>/dev/null)

  ppa_deb_file=$(find "${PPA_DIR}/pool/main" -type f -name "${pkg_name}_*.deb" 2>/dev/null | head -n 1 || true)
  proj_sha256=""
  ppa_sha256=""
  if [ -n "$proj_deb_file" ] && [ -e "$proj_deb_file" ]; then
    proj_sha256=$(sha256sum "$(readlink -f "$proj_deb_file")" | awk '{print $1}')
  fi
  if [ -n "$ppa_deb_file" ] && [ -f "$ppa_deb_file" ]; then
    ppa_sha256=$(sha256sum "$ppa_deb_file" | awk '{print $1}')
  fi

  if [ -n "$latest_deb_ver" ] && { [ -z "$ppa_ver" ] || [ "$latest_deb_ver" != "$ppa_ver" ] || [ "$proj_sha256" != "$ppa_sha256" ]; }; then
    log "[$pkg_name] Update ready for PPA: ${ppa_ver:-none} -> ${latest_deb_ver}"
    NEED_PPA_REBUILD=1
    UPDATED_PACKAGES+=("${pkg_name} (${ppa_ver:-new} -> ${latest_deb_ver})")
  fi

  set_state_val "${pkg_name}_sha" "$current_sha"
  set_state_val "${pkg_name}_version" "${latest_deb_ver}"

  popd >/dev/null
done

if [ "$FORCE_REBUILD" -eq 1 ]; then
  log "Force rebuild requested (--force)."
  NEED_PPA_REBUILD=1
fi

if [ "$NEED_PPA_REBUILD" -eq 0 ]; then
  log "All PPA packages are up-to-date with the latest versions. Nothing to rebuild."
  exit 0
fi

SUMMARY_STR=$(IFS=', '; echo "${UPDATED_PACKAGES[*]:-manual rebuild}")
log "Rebuilding Arda-Tech PPA for updated packages: ${SUMMARY_STR}"

"${PPA_DIR}/scripts/build-ppa.sh"

if [ "$SKIP_PUSH" -eq 1 ]; then
  log "Skipping git commit/push (--no-push)."
  exit 0
fi

# Commit & push arda-tech-ppa (main and gh-pages)
log "Committing and pushing updates to arda-tech-ppa..."
pushd "$PPA_DIR" >/dev/null
git add .gitignore pool dists index.html README.md KEY.asc KEY.gpg arda-tech.gpg arda-tech-archive-keyring.gpg scripts/build-ppa.sh scripts/auto-update-ppa.sh
if ! git diff --cached --quiet; then
  git commit -m "chore(ppa): auto-update packages (${SUMMARY_STR})"
  git push origin main
  git push origin main:gh-pages --force
  log "Successfully pushed arda-tech-ppa to origin/main and origin/gh-pages!"
else
  log "No git changes to commit in arda-tech-ppa."
fi
popd >/dev/null

# Commit & push arda-tech (main)
if [ -d "$ARDA_TECH_DIR/.git" ]; then
  log "Committing and pushing synchronized APT pool/dists & apps.json to arda-tech..."
  pushd "$ARDA_TECH_DIR" >/dev/null
  git add pool dists apps.json README.md
  if ! git diff --cached --quiet; then
    git commit -m "chore(ppa): auto-update APT packages (${SUMMARY_STR})"
    git push origin main
    log "Successfully pushed arda-tech to origin/main!"
  else
    log "No git changes to commit in arda-tech."
  fi
  popd >/dev/null
fi

log "PPA auto-update pipeline completed successfully!"
