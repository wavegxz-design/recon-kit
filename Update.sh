#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║         RECON-KIT — Auto-Update Module v2.1.1               ║
# ║         Author  : krypthane | wavegxz-design                ║
# ║         Site    : krypthane.workernova.workers.dev           ║
# ║         GitHub  : github.com/wavegxz-design/recon-kit       ║
# ╚══════════════════════════════════════════════════════════════╝

# ── COLORS ──────────────────────────────────────────────────────
_R='\033[0;31m' _G='\033[0;32m' _Y='\033[1;33m'
_C='\033[0;36m' _W='\033[1;37m' _DIM='\033[2m'
_M='\033[0;35m' _BOLD='\033[1m' _N='\033[0m'

_OK="${_G}[✔]${_N}"   _ERR="${_R}[✘]${_N}"  _INF="${_C}[*]${_N}"
_WRN="${_Y}[!]${_N}"  _ACT="${_M}[→]${_N}"  _FIX="${_C}[⚙]${_N}"

# ── CONSTANTS ───────────────────────────────────────────────────
readonly _REPO_OWNER="wavegxz-design"
readonly _REPO_NAME="recon-kit"
readonly _REPO_URL="https://github.com/${_REPO_OWNER}/${_REPO_NAME}"
readonly _RAW_URL="https://raw.githubusercontent.com/${_REPO_OWNER}/${_REPO_NAME}/main"
readonly _API_RELEASES="https://api.github.com/repos/${_REPO_OWNER}/${_REPO_NAME}/releases/latest"
readonly _API_TAGS="https://api.github.com/repos/${_REPO_OWNER}/${_REPO_NAME}/tags"
readonly _SITE="krypthane.workernova.workers.dev"

# ── RESOLVE PATHS ───────────────────────────────────────────────
# FIX: resolve update.sh location reliably regardless of how it's called
_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_MAIN_SCRIPT="${_SELF_DIR}/recon-kit.sh"
_UPDATE_CACHE="${RECON_KIT_DIR:-$HOME/.recon-kit}/cache/last_update_check"
_BACKUP_DIR="${_SELF_DIR}"

# ── HELPERS ─────────────────────────────────────────────────────
_sep()  { echo -e "${_DIM}──────────────────────────────────────────────────────────${_N}"; }
_log()  { echo -e " ${_OK} ${_W}$*${_N}"; }
_info() { echo -e " ${_INF} $*"; }
_warn() { echo -e " ${_WRN} ${_Y}$*${_N}"; }
_err()  { echo -e " ${_ERR} ${_R}$*${_N}"; }
_act()  { echo -e " ${_ACT} ${_C}$*${_N}"; }
_fix()  { echo -e " ${_FIX} ${_C}$*${_N}"; }

_spinner() {
  local pid=$1 msg=${2:-"Working..."}
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' si=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${_C}${spin:si++%${#spin}:1}${_N}  ${_DIM}%s${_N}" "$msg"
    sleep 0.08
  done
  printf "\r%*s\r" 60 ""
}

# ── CHECK DEPENDENCIES ──────────────────────────────────────────
_check_deps() {
  local missing=()
  for dep in curl git; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    _err "Missing required tools: ${missing[*]}"
    _info "Install with: sudo apt install ${missing[*]}"
    return 1
  fi
  return 0
}

# ── CHECK INTERNET ───────────────────────────────────────────────
_check_internet() {
  curl -sf --max-time 5 https://api.github.com &>/dev/null && return 0
  curl -sf --max-time 5 https://1.1.1.1 &>/dev/null && {
    _warn "Reached internet but GitHub API may be blocked"
    return 0
  }
  _err "No internet connection detected"
  return 1
}

# ── GET CURRENT VERSION ─────────────────────────────────────────
# FIX: multiple fallback methods to read current version
_get_current_version() {
  local ver=""

  # Method 1: from main script VERSION= line
  if [[ -f "$_MAIN_SCRIPT" ]]; then
    ver=$(grep -m1 '^readonly VERSION=' "$_MAIN_SCRIPT" 2>/dev/null \
      | cut -d'"' -f2 || true)
    [[ -n "$ver" ]] && { echo "$ver"; return 0; }

    # Try without readonly (older versions)
    ver=$(grep -m1 '^VERSION=' "$_MAIN_SCRIPT" 2>/dev/null \
      | cut -d'"' -f2 || true)
    [[ -n "$ver" ]] && { echo "$ver"; return 0; }
  fi

  # Method 2: from git tags in the repo
  if command -v git &>/dev/null && \
     git -C "$_SELF_DIR" rev-parse --git-dir &>/dev/null; then
    ver=$(git -C "$_SELF_DIR" describe --tags --abbrev=0 2>/dev/null | tr -d 'v' || true)
    [[ -n "$ver" ]] && { echo "$ver"; return 0; }
  fi

  # Method 3: from VERSION file
  if [[ -f "${_SELF_DIR}/VERSION" ]]; then
    ver=$(cat "${_SELF_DIR}/VERSION" | tr -d 'v\n\r ' || true)
    [[ -n "$ver" ]] && { echo "$ver"; return 0; }
  fi

  echo "0.0.0"   # unknown — treat as always outdated
}

# ── FETCH LATEST VERSION ────────────────────────────────────────
# FIX: try releases first, fall back to tags API
_fetch_latest_version() {
  local tag=""

  # Method 1: GitHub releases/latest API
  _fix "Trying releases API..."
  local rel_resp
  rel_resp=$(curl -sf --max-time 15 \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: recon-kit-updater" \
    "$_API_RELEASES" 2>/dev/null) || true

  if [[ -n "$rel_resp" ]]; then
    tag=$(echo "$rel_resp" | grep '"tag_name"' | head -1 | cut -d'"' -f4 | tr -d 'v' || true)
  fi

  # Method 2: fallback to tags API (works even without a formal release)
  if [[ -z "$tag" ]]; then
    _fix "No release found — trying tags API..."
    local tags_resp
    tags_resp=$(curl -sf --max-time 15 \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: recon-kit-updater" \
      "$_API_TAGS" 2>/dev/null) || true

    if [[ -n "$tags_resp" ]]; then
      tag=$(echo "$tags_resp" | grep '"name"' | head -1 | cut -d'"' -f4 | tr -d 'v' || true)
    fi
  fi

  # Method 3: parse GitHub releases page (HTML scrape fallback)
  if [[ -z "$tag" ]]; then
    _fix "Trying GitHub releases page..."
    tag=$(curl -sf --max-time 15 \
      -H "User-Agent: recon-kit-updater" \
      "https://github.com/${_REPO_OWNER}/${_REPO_NAME}/releases" 2>/dev/null \
      | grep -oP '(?<=releases/tag/)[^"]+' | head -1 | tr -d 'v' || true)
  fi

  # Method 4: read VERSION file from raw GitHub
  if [[ -z "$tag" ]]; then
    _fix "Reading VERSION file from repo..."
    tag=$(curl -sf --max-time 10 "${_RAW_URL}/VERSION" 2>/dev/null \
      | tr -d 'v\n\r ' || true)
  fi

  if [[ -z "$tag" ]]; then
    _err "Could not determine latest version from any source"
    _info "Possible reasons:"
    _info "  → No releases or tags published yet on GitHub"
    _info "  → Run: git tag v2.1.1 && git push origin v2.1.1"
    _info "  → Then go to GitHub → Releases → Create release from tag"
    return 1
  fi

  echo "$tag"
}

# ── VERSION COMPARISON ──────────────────────────────────────────
_version_int() {
  local v="${1#v}"
  local major=0 minor=0 patch=0
  IFS='.' read -r major minor patch <<< "$v"
  echo $(( (${major:-0} * 1000000) + (${minor:-0} * 1000) + ${patch:-0} ))
}

# ── SHOW CHANGELOG ──────────────────────────────────────────────
_show_changelog() {
  local current="$1" latest="$2"
  _info "Fetching changelog..."
  local cl; cl=$(curl -sf --max-time 10 "${_RAW_URL}/CHANGELOG.md" 2>/dev/null) || {
    _warn "CHANGELOG.md not found in repo — skipping"
    return
  }
  echo ""
  echo -e "  ${_W}Changes ${current} → ${latest}:${_N}"
  _sep
  local printing=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE "^## \[?v?${latest}"; then printing=true; fi
    if echo "$line" | grep -qE "^## \[?v?${current}" && $printing; then break; fi
    $printing && echo -e "  ${_DIM}${line}${_N}"
  done <<< "$cl"
  _sep
}

# ── BACKUP ──────────────────────────────────────────────────────
_backup_current() {
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local bak="${_BACKUP_DIR}/recon-kit_backup_${ts}.sh"
  cp "$_MAIN_SCRIPT" "$bak" 2>/dev/null && {
    _log "Backup → ${_C}${bak}${_N}"
    echo "$bak"
    return 0
  }
  _err "Could not create backup — aborting"
  return 1
}

# ── DOWNLOAD & APPLY ────────────────────────────────────────────
_apply_update() {
  local latest_tag="$1"
  local raw_url="${_RAW_URL}/recon-kit.sh"
  local tmp; tmp=$(mktemp /tmp/recon-kit-update-XXXXXX.sh)

  _act "Downloading recon-kit v${latest_tag}..."
  if ! curl -sf --max-time 60 \
    -H "User-Agent: recon-kit-updater" \
    "$raw_url" -o "$tmp" 2>/dev/null; then
    _err "Download failed from: $raw_url"
    rm -f "$tmp"
    return 1
  fi

  # Validate: not empty
  if [[ ! -s "$tmp" ]]; then
    _err "Downloaded file is empty"
    rm -f "$tmp"; return 1
  fi

  # Validate: bash syntax
  if ! bash -n "$tmp" 2>/dev/null; then
    _err "Downloaded file failed syntax check — aborting"
    rm -f "$tmp"; return 1
  fi

  # Validate: has shebang
  if ! head -1 "$tmp" | grep -q "bash"; then
    _err "Downloaded file doesn't look like a bash script"
    rm -f "$tmp"; return 1
  fi

  # Apply
  if mv "$tmp" "$_MAIN_SCRIPT" && chmod +x "$_MAIN_SCRIPT"; then
    return 0
  fi

  _err "Could not replace script — check permissions on $_MAIN_SCRIPT"
  rm -f "$tmp"
  return 1
}

# ── LAST CHECK TIMESTAMP ────────────────────────────────────────
_record_check() {
  mkdir -p "$(dirname "$_UPDATE_CACHE")" 2>/dev/null || true
  date +%s > "$_UPDATE_CACHE" 2>/dev/null || true
}

_should_check() {
  [[ ! -f "$_UPDATE_CACHE" ]] && return 0
  local last; last=$(cat "$_UPDATE_CACHE" 2>/dev/null || echo 0)
  local now;  now=$(date +%s)
  [[ $(( now - last )) -gt 86400 ]]
}

# ══════════════════════════════════════════════════════════════════
# PUBLIC API — called from recon-kit.sh
# ══════════════════════════════════════════════════════════════════

# Silent background check (called at startup)
auto_check_update() {
  local current_ver="${1:-$(_get_current_version)}"
  _should_check || return 0
  _record_check
  (
    _check_internet &>/dev/null || exit 0
    local latest; latest=$(_fetch_latest_version 2>/dev/null) || exit 0
    local cur_i; cur_i=$(_version_int "$current_ver")
    local lat_i; lat_i=$(_version_int "$latest")
    if [[ $lat_i -gt $cur_i ]]; then
      echo ""
      echo -e " ${_Y}┌────────────────────────────────────────────────────────┐${_N}"
      echo -e " ${_Y}│${_N}  ${_W}Update available: v${current_ver} → v${latest}${_N}"
      echo -e " ${_Y}│${_N}  ${_DIM}Run: ./recon-kit.sh --update${_N}"
      echo -e " ${_Y}│${_N}  ${_DIM}${_SITE}${_N}"
      echo -e " ${_Y}└────────────────────────────────────────────────────────┘${_N}"
      echo ""
    fi
  ) &
}

# Interactive update
run_update() {
  local current_ver="${1:-$(_get_current_version)}"

  echo ""
  echo -e "  ${_W}${_BOLD}RECON-KIT UPDATE MANAGER${_N}"
  echo -e "  ${_DIM}krypthane | wavegxz-design | ${_SITE}${_N}"
  _sep

  _check_deps || return 1
  _check_internet || {
    _err "No internet — cannot check for updates"
    return 1
  }

  _info "Current version : ${_W}v${current_ver}${_N}"
  _info "Script path     : ${_W}${_MAIN_SCRIPT}${_N}"
  _act  "Checking latest release..."

  local latest; latest=$(_fetch_latest_version) || return 1
  _info "Latest version  : ${_W}v${latest}${_N}"

  local cur_i; cur_i=$(_version_int "$current_ver")
  local lat_i; lat_i=$(_version_int "$latest")

  if [[ $lat_i -le $cur_i ]]; then
    _log "Already up to date — ${_C}v${current_ver}${_N} is the latest"
    _record_check
    return 0
  fi

  echo ""
  _warn "New version: ${_Y}v${current_ver}${_N} → ${_G}v${latest}${_N}"
  _show_changelog "$current_ver" "$latest"

  printf "  ${_C}[>]${_N} Update now? [y/N] "
  read -r confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { _info "Update cancelled"; return 0; }

  if [[ ! -f "$_MAIN_SCRIPT" ]]; then
    _err "Main script not found: $_MAIN_SCRIPT"
    _info "Make sure update.sh is in the same directory as recon-kit.sh"
    return 1
  fi

  _act "Creating backup..."
  local backup; backup=$(_backup_current) || return 1

  _act "Downloading v${latest}..."
  if _apply_update "$latest"; then
    _log "Updated to ${_G}v${latest}${_N} successfully"
    _info "Backup kept at → ${_DIM}${backup}${_N}"
    _info "Restart recon-kit to use the new version"
    _record_check
  else
    _err "Update failed — restoring backup..."
    if cp "$backup" "$_MAIN_SCRIPT" && chmod +x "$_MAIN_SCRIPT"; then
      _log "Restored to v${current_ver} from backup"
    else
      _err "Restore also failed — manual fix:"
      _err "cp '$backup' '$_MAIN_SCRIPT'"
    fi
    return 1
  fi
}

# Check only — no install
run_check() {
  local current_ver="${1:-$(_get_current_version)}"
  echo ""
  echo -e "  ${_W}${_BOLD}RECON-KIT UPDATE CHECK${_N}"
  echo -e "  ${_DIM}${_SITE}${_N}"
  _sep

  _check_deps   || return 1
  _check_internet || { _err "No internet connection"; return 1; }

  _info "Current : ${_W}v${current_ver}${_N}"
  _act  "Fetching latest version..."

  local latest; latest=$(_fetch_latest_version) || return 1
  _info "Latest  : ${_W}v${latest}${_N}"

  local cur_i; cur_i=$(_version_int "$current_ver")
  local lat_i; lat_i=$(_version_int "$latest")

  if [[ $lat_i -gt $cur_i ]]; then
    echo ""
    _warn "Update available: v${current_ver} → v${latest}"
    _info "Run: ./recon-kit.sh --update"
    _info "  or: bash update.sh"
  else
    _log "Up to date — v${current_ver} is the latest"
  fi

  _record_check
}

# Rollback from backup
run_rollback() {
  echo ""
  echo -e "  ${_W}${_BOLD}RECON-KIT ROLLBACK${_N}"
  _sep

  local backups=()
  while IFS= read -r f; do
    backups+=("$f")
  done < <(ls -t "${_BACKUP_DIR}"/recon-kit_backup_*.sh 2>/dev/null)

  if [[ ${#backups[@]} -eq 0 ]]; then
    _warn "No backups found in: ${_BACKUP_DIR}"
    _info "Backups are created automatically before each update"
    return 1
  fi

  _info "Available backups:"
  _sep
  local idx=1
  for b in "${backups[@]}"; do
    local bver; bver=$(grep -m1 'VERSION=' "$b" 2>/dev/null | cut -d'"' -f2 || echo "?")
    local bdate; bdate=$(basename "$b" | grep -oP '\d{8}_\d{6}' || echo "unknown")
    printf "  ${_C}%d${_N}) ${_W}%-40s${_N}  ${_DIM}v%s — %s${_N}\n" \
      "$idx" "$(basename "$b")" "$bver" "$bdate"
    idx=$((idx+1))
  done
  _sep

  printf "  ${_C}[>]${_N} Select backup (1-%d) or q to quit: " "${#backups[@]}"
  read -r sel

  [[ "$sel" == "q" || "$sel" == "Q" ]] && { _info "Rollback cancelled"; return 0; }

  if ! [[ "$sel" =~ ^[0-9]+$ ]] || \
     [[ $sel -lt 1 ]] || \
     [[ $sel -gt ${#backups[@]} ]]; then
    _err "Invalid selection: '$sel'"
    return 1
  fi

  local chosen="${backups[$((sel-1))]}"
  local chosen_ver; chosen_ver=$(grep -m1 'VERSION=' "$chosen" 2>/dev/null | cut -d'"' -f2 || echo "?")
  echo ""
  printf "  ${_C}[>]${_N} Restore ${_W}v%s${_N} from %s? [y/N] " "$chosen_ver" "$(basename "$chosen")"
  read -r confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { _info "Rollback cancelled"; return 0; }

  if cp "$chosen" "$_MAIN_SCRIPT" && chmod +x "$_MAIN_SCRIPT"; then
    _log "Rolled back to v${chosen_ver}"
    _info "Restart recon-kit to apply"
  else
    _err "Rollback failed — check permissions on $_MAIN_SCRIPT"
    return 1
  fi
}

# ══════════════════════════════════════════════════════════════════
# STANDALONE MODE — bash update.sh [--check|--rollback]
# ══════════════════════════════════════════════════════════════════
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CURRENT_VER=$(_get_current_version)

  case "${1:-}" in
    --rollback|-r) run_rollback ;;
    --check|-c)    run_check "$CURRENT_VER" ;;
    --help|-h)
      echo -e "${_W}Usage:${_N} bash update.sh [option]"
      echo -e "  (no args)    Check and apply latest update"
      echo -e "  --check      Check without installing"
      echo -e "  --rollback   Restore previous version"
      echo -e "  --help       This help"
      ;;
    *)             run_update "$CURRENT_VER" ;;
  esac
fi
