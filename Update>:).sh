#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║         RECON-KIT — Auto-Update Module                      ║
# ║         Author  : krypthane | wavegxz-design                ║
# ║         Site    : krypthane.workernova.workers.dev           ║
# ║         GitHub  : github.com/wavegxz-design/recon-kit       ║
# ╚══════════════════════════════════════════════════════════════╝

# ── COLORS (standalone — works even if sourced before main) ─────
_R='\033[0;31m' _G='\033[0;32m' _Y='\033[1;33m'
_C='\033[0;36m' _W='\033[1;37m' _DIM='\033[2m' _N='\033[0m'
_OK="${_G}[✔]${_N}" _ERR="${_R}[✘]${_N}" _INF="${_C}[*]${_N}"
_WRN="${_Y}[!]${_N}" _ACT='\033[0;35m[→]\033[0m'

# ── CONSTANTS ───────────────────────────────────────────────────
REPO_OWNER="wavegxz-design"
REPO_NAME="recon-kit"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main"
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
INSTALL_PATH="${BASH_SOURCE[0]%/*}/recon-kit.sh"   # same dir as update.sh
UPDATE_CACHE="${RECON_KIT_DIR:-$HOME/.recon-kit}/cache/last_update_check"
CHANGELOG_URL="${RAW_URL}/CHANGELOG.md"

# ── HELPERS ─────────────────────────────────────────────────────
_sep()  { echo -e "${_DIM}──────────────────────────────────────────────────────────${_N}"; }
_log()  { echo -e " ${_OK} ${_W}$*${_N}"; }
_info() { echo -e " ${_INF} $*"; }
_warn() { echo -e " ${_WRN} ${_Y}$*${_N}"; }
_err()  { echo -e " ${_ERR} ${_R}$*${_N}"; }
_act()  { echo -e " ${_ACT} ${_C}$*${_N}"; }

_spinner() {
  local pid=$1 msg=${2:-"Working..."}
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' si=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${_C}${spin:si++%${#spin}:1}${_N}  ${_DIM}%s${_N}" "$msg"
    sleep 0.08
  done
  printf "\r%*s\r" 60 ""
}

# ── VERSION PARSING ─────────────────────────────────────────────
# Converts "v2.1.0" → 2001000 for numeric comparison
version_int() {
  local v="${1#v}"      # strip leading v
  local major minor patch
  IFS='.' read -r major minor patch <<< "$v"
  echo $(( (${major:-0} * 1000000) + (${minor:-0} * 1000) + ${patch:-0} ))
}

# ── FETCH LATEST VERSION FROM GITHUB API ────────────────────────
fetch_latest_version() {
  local response
  response=$(curl -sf --max-time 10 \
    -H "Accept: application/vnd.github+json" \
    "$API_URL" 2>/dev/null) || {
    _warn "Could not reach GitHub API — check your connection"
    return 1
  }

  local tag; tag=$(echo "$response" | grep '"tag_name"' | cut -d'"' -f4)
  [[ -z "$tag" ]] && { _warn "Could not parse latest version from API"; return 1; }
  echo "$tag"
}

# ── SHOW CHANGELOG BETWEEN VERSIONS ────────────────────────────
show_changelog() {
  local current="$1" latest="$2"
  _info "Fetching changelog..."
  local cl; cl=$(curl -sf --max-time 10 "$CHANGELOG_URL" 2>/dev/null) || {
    _warn "Could not fetch CHANGELOG.md"
    return
  }

  echo ""
  echo -e "  ${_W}Changes from ${current} → ${latest}:${_N}"
  _sep

  # Print only lines between the latest version header and the previous one
  local printing=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE "^## \[?${latest#v}"; then
      printing=true
    elif echo "$line" | grep -qE "^## \[?${current#v}"; then
      break
    fi
    $printing && echo -e "  ${_DIM}${line}${_N}"
  done <<< "$cl"
  _sep
}

# ── BACKUP CURRENT VERSION ──────────────────────────────────────
backup_current() {
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local backup_path="${INSTALL_PATH%.sh}_backup_${ts}.sh"
  cp "$INSTALL_PATH" "$backup_path" 2>/dev/null && {
    _log "Backup saved → ${_C}$backup_path${_N}"
    echo "$backup_path"
  } || {
    _warn "Could not create backup — update aborted"
    return 1
  }
}

# ── DOWNLOAD AND APPLY UPDATE ───────────────────────────────────
apply_update() {
  local latest_tag="$1"
  local script_url="${RAW_URL}/recon-kit.sh"
  local tmp_file; tmp_file=$(mktemp /tmp/recon-kit-update-XXXXXX.sh)

  _act "Downloading v${latest_tag#v}..."
  curl -sf --max-time 30 --progress-bar \
    "$script_url" -o "$tmp_file" 2>/dev/null & _spinner $! "Downloading update..."

  # Validate download
  if [[ ! -s "$tmp_file" ]]; then
    _err "Download failed or file is empty"
    rm -f "$tmp_file"
    return 1
  fi

  # Verify it's a valid bash script
  if ! bash -n "$tmp_file" 2>/dev/null; then
    _err "Downloaded file failed syntax check — aborting update"
    rm -f "$tmp_file"
    return 1
  fi

  # Verify it contains the version string we expect
  if ! grep -q "VERSION=\"${latest_tag#v}\"" "$tmp_file" 2>/dev/null; then
    _warn "Version mismatch in downloaded file — proceeding anyway"
  fi

  # Replace current script
  mv "$tmp_file" "$INSTALL_PATH" && chmod +x "$INSTALL_PATH" || {
    _err "Could not replace script — check permissions"
    rm -f "$tmp_file"
    return 1
  }

  return 0
}

# ── RECORD LAST CHECK TIMESTAMP ─────────────────────────────────
record_check() {
  mkdir -p "$(dirname "$UPDATE_CACHE")"
  date +%s > "$UPDATE_CACHE"
}

# ── SHOULD AUTO-CHECK? (once per 24h) ───────────────────────────
should_check() {
  [[ ! -f "$UPDATE_CACHE" ]] && return 0
  local last; last=$(cat "$UPDATE_CACHE" 2>/dev/null || echo 0)
  local now;  now=$(date +%s)
  local diff=$(( now - last ))
  [[ $diff -gt 86400 ]]   # true if >24h since last check
}

# ══════════════════════════════════════════════════════════════════
# PUBLIC FUNCTIONS
# ══════════════════════════════════════════════════════════════════

# Silent background check — call at startup in main bot
# Usage: auto_check_update "2.1.0"
auto_check_update() {
  local current_ver="$1"
  should_check || return 0
  record_check

  (
    local latest; latest=$(fetch_latest_version 2>/dev/null) || exit 0
    local cur_int; cur_int=$(version_int "$current_ver")
    local lat_int; lat_int=$(version_int "$latest")
    if [[ $lat_int -gt $cur_int ]]; then
      echo ""
      echo -e " ${_Y}┌────────────────────────────────────────────────────────┐${_N}"
      echo -e " ${_Y}│${_N}  ${_W}Update available: ${current_ver} → ${latest}${_N}"
      echo -e " ${_Y}│${_N}  ${_DIM}Run: ./recon-kit.sh --update  or  bash update.sh${_N}"
      echo -e " ${_Y}│${_N}  ${_DIM}Site: krypthane.workernova.workers.dev${_N}"
      echo -e " ${_Y}└────────────────────────────────────────────────────────┘${_N}"
      echo ""
    fi
  ) &   # completely non-blocking
}

# Interactive update — call with --update flag
# Usage: run_update "2.1.0"
run_update() {
  local current_ver="$1"

  echo ""
  echo -e "  ${_W}RECON-KIT UPDATE MANAGER${_N}"
  echo -e "  ${_DIM}krypthane | wavegxz-design | krypthane.workernova.workers.dev${_N}"
  _sep

  _info "Current version : ${_W}${current_ver}${_N}"
  _act  "Checking latest release..."

  local latest; latest=$(fetch_latest_version) || {
    _err "Update check failed — try again later"
    return 1
  }

  _info "Latest version  : ${_W}${latest}${_N}"

  local cur_int; cur_int=$(version_int "$current_ver")
  local lat_int; lat_int=$(version_int "$latest")

  if [[ $lat_int -le $cur_int ]]; then
    _log "Already up to date — ${_C}${current_ver}${_N} is the latest"
    record_check
    return 0
  fi

  echo ""
  _warn "New version available: ${_Y}${current_ver}${_N} → ${_G}${latest}${_N}"
  show_changelog "$current_ver" "$latest"

  echo -ne "  ${_C}[>]${_N} Update now? [y/N] "
  read -r confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { _info "Update cancelled"; return 0; }

  # Backup
  _act "Creating backup of current version..."
  local backup; backup=$(backup_current) || return 1

  # Download and apply
  if apply_update "$latest"; then
    _log "Update successful → ${_G}${latest}${_N}"
    _info "Backup kept at  → ${_DIM}${backup}${_N}"
    _info "Restart recon-kit to use the new version"
    record_check
  else
    _err "Update failed — restoring backup..."
    cp "$backup" "$INSTALL_PATH" && chmod +x "$INSTALL_PATH" && {
      _log "Restored to ${current_ver} from backup"
    } || _err "Restore failed — manual fix required: cp $backup $INSTALL_PATH"
    return 1
  fi
}

# Rollback to a backup
# Usage: run_rollback
run_rollback() {
  local backup_dir; backup_dir="${INSTALL_PATH%/*}"
  local backups; mapfile -t backups < <(ls -t "${backup_dir}"/recon-kit_backup_*.sh 2>/dev/null)

  if [[ ${#backups[@]} -eq 0 ]]; then
    _warn "No backups found in ${backup_dir}"
    return 1
  fi

  echo ""
  echo -e "  ${_W}Available backups:${_N}"
  _sep
  local idx=1
  for b in "${backups[@]}"; do
    local bver; bver=$(grep 'VERSION=' "$b" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "?")
    printf "  ${_C}%d${_N}) ${_W}%s${_N}  ${_DIM}(v%s)${_N}\n" "$idx" "$(basename "$b")" "$bver"
    idx=$((idx+1))
  done
  _sep

  printf "  ${_C}[>]${_N} Select backup (1-%d): " "${#backups[@]}"
  read -r sel

  if ! [[ "$sel" =~ ^[0-9]+$ ]] || [[ $sel -lt 1 ]] || [[ $sel -gt ${#backups[@]} ]]; then
    _err "Invalid selection"; return 1
  fi

  local chosen="${backups[$((sel-1))]}"
  printf "  ${_C}[>]${_N} Restore ${_W}$(basename "$chosen")${_N}? [y/N] "
  read -r confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { _info "Rollback cancelled"; return 0; }

  cp "$chosen" "$INSTALL_PATH" && chmod +x "$INSTALL_PATH" && {
    _log "Rolled back to $(basename "$chosen")"
    _info "Restart recon-kit to apply"
  } || _err "Rollback failed — check permissions"
}

# ══════════════════════════════════════════════════════════════════
# STANDALONE MODE — run directly: bash update.sh
# ══════════════════════════════════════════════════════════════════
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Get current version from main script if exists
  CURRENT_VER="unknown"
  if [[ -f "$INSTALL_PATH" ]]; then
    CURRENT_VER=$(grep 'VERSION=' "$INSTALL_PATH" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")
  fi

  case "${1:-}" in
    --rollback|-r) run_rollback ;;
    --check|-c)
      _act "Checking for updates..."
      latest=$(fetch_latest_version) && {
        cur_int=$(version_int "$CURRENT_VER")
        lat_int=$(version_int "$latest")
        if [[ $lat_int -gt $cur_int ]]; then
          _warn "Update available: ${CURRENT_VER} → ${latest}"
          _info "Run: bash update.sh  to update"
        else
          _log "Up to date — ${CURRENT_VER}"
        fi
      }
      ;;
    *)
      run_update "$CURRENT_VER"
      ;;
  esac
fi
