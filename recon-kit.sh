#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              RECON-KIT v2.1.1 — Reconnaissance Toolkit       ║
# ║         Author  : krypthane | wavegxz-design                 ║
# ║         Site    : krypthane.workernova.workers.dev           ║
# ║         GitHub  : github.com/wavegxz-design/recon-kit        ║
# ║         License : MIT                                        ║
# ║                                                              ║
# ║   USE ONLY ON SYSTEMS YOU OWN OR HAVE WRITTEN PERMISSION.    ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Intentionally NOT using set -euo pipefail globally.
# Each command handles its own errors explicitly — senior pattern.
# Unbound vars are caught per-function with explicit guards.

# ── VERSION ─────────────────────────────────────────────────────
readonly VERSION="2.1.2"
readonly SITE="krypthane.workernova.workers.dev"
readonly RECON_KIT_DIR="${RECON_KIT_DIR:-$HOME/.recon-kit}"
readonly PLUGINS_DIR="$RECON_KIT_DIR/plugins"
readonly CACHE_DIR="$RECON_KIT_DIR/cache"
readonly CONFIG_FILE="$RECON_KIT_DIR/config"
readonly LOG_BOOT="/tmp/recon-kit-boot-$$.log"

# ── COLORS ──────────────────────────────────────────────────────
R='\033[0;31m'   G='\033[0;32m'   Y='\033[1;33m'
B='\033[0;34m'   C='\033[0;36m'   M='\033[0;35m'
W='\033[1;37m'   DIM='\033[2m'    BOLD='\033[1m'   N='\033[0m'

OK="${G}[✔]${N}"   ERR="${R}[✘]${N}"   INF="${C}[*]${N}"
WRN="${Y}[!]${N}"  ACT="${M}[→]${N}"   FIX="${B}[⚙]${N}"
CRT="${R}[CRITICAL]${N}"

# ── RUNTIME STATE ───────────────────────────────────────────────
TARGET=""
OUTPUT_DIR=""
MODULES=()
LOG_FILE="$LOG_BOOT"
START_TIME=$(date +%s)
ERRORS=()       # collect non-fatal errors for final report
WARNINGS=()     # collect warnings for final report
WORDLIST=""     # FIX: external subdomain wordlist path (-w flag)

# ══════════════════════════════════════════════════════════════════
# TRAP & SIGNAL HANDLING
# ══════════════════════════════════════════════════════════════════
_cleanup() {
  local exit_code=$?
  # Kill any background jobs spawned by this script
  local bg_jobs
  bg_jobs=$(jobs -p 2>/dev/null || true)
  if [[ -n "$bg_jobs" ]]; then
    echo -e "\n ${WRN} Cleaning up background processes..." >&2
    echo "$bg_jobs" | xargs -r kill 2>/dev/null || true
  fi
  # Remove temp files
  rm -f "$LOG_BOOT" 2>/dev/null || true
  [[ $exit_code -ne 0 && $exit_code -ne 130 ]] && \
    echo -e " ${ERR} Exited with code $exit_code" >&2
}
trap '_cleanup' EXIT

_handle_interrupt() {
  echo -e "\n\n ${WRN} ${Y}Interrupted by user (Ctrl+C)${N}"
  echo -e " ${INF} Partial output saved → ${Y}${OUTPUT_DIR:-/tmp}${N}"
  exit 130
}
trap '_handle_interrupt' INT TERM

# ══════════════════════════════════════════════════════════════════
# LOGGING
# ══════════════════════════════════════════════════════════════════
log()  { echo -e " ${OK} ${W}$*${N}"  | tee -a "$LOG_FILE"; }
info() { echo -e " ${INF} $*"         | tee -a "$LOG_FILE"; }
warn() {
  local msg="$*"
  echo -e " ${WRN} ${Y}${msg}${N}" | tee -a "$LOG_FILE"
  WARNINGS+=("$msg")
}
err()  {
  local msg="$*"
  echo -e " ${ERR} ${R}${msg}${N}" | tee -a "$LOG_FILE"
  ERRORS+=("$msg")
}
act()  { echo -e " ${ACT} ${C}$*${N}" | tee -a "$LOG_FILE"; }
fix()  { echo -e " ${FIX} ${B}$*${N}" | tee -a "$LOG_FILE"; }
crit() {
  local msg="$*"
  echo -e " ${CRT} ${R}${BOLD}${msg}${N}" | tee -a "$LOG_FILE"
  ERRORS+=("[CRITICAL] $msg")
}

# ══════════════════════════════════════════════════════════════════
# UI HELPERS
# ══════════════════════════════════════════════════════════════════
banner() {
  clear
  echo -e "${G}"
cat << 'EOF'
  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗      ██╗  ██╗██╗████████╗
  ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║      ██║ ██╔╝██║╚══██╔══╝
  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║█████╗█████╔╝ ██║   ██║
  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║╚════╝██╔═██╗ ██║   ██║
  ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║      ██║  ██╗██║   ██║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝      ╚═╝  ╚═╝╚═╝   ╚═╝
EOF
  echo -e "${N}"
  printf "  ${W}v%s${N}  ${DIM}|${N}  ${C}krypthane${N}  ${DIM}|${N}  ${Y}%s${N}\n" \
    "$VERSION" "github.com/wavegxz-design/recon-kit"
  echo -e "  ${DIM}Modular Recon Toolkit — Authorized penetration testing only${N}"
  echo -e "  ${DIM}${SITE}${N}"
  echo -e "  ${R}[!] Unauthorized use is illegal. You are responsible for your actions.${N}"
  sep_full
}

sep_full() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"; }
sep()      { echo -e "${DIM}──────────────────────────────────────────────────────────────${N}"; }

section() {
  echo "" | tee -a "$LOG_FILE"
  echo -e " ${M}┌─────────────────────────────────────────────┐${N}" | tee -a "$LOG_FILE"
  printf " ${M}│${N}  ${W}${BOLD}%-43s${N}\n" "$*" | tee -a "$LOG_FILE"
  echo -e " ${M}└─────────────────────────────────────────────┘${N}" | tee -a "$LOG_FILE"
}

header_box() {
  local t="$1"
  local len=${#t}
  local border; border=$(printf '─%.0s' $(seq 1 $((len+4))))
  echo -e "\n  ${C}┌${border}┐${N}"
  echo -e "  ${C}│${N}  ${W}${BOLD}${t}${N}  ${C}│${N}"
  echo -e "  ${C}└${border}┘${N}\n"
}

spinner() {
  local pid=$1 msg=${2:-"Working..."}
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' si=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${spin:si++%${#spin}:1}${N}  ${DIM}%s${_N}" "$msg"
    sleep 0.08
  done
  printf "\r%*s\r" 60 ""
}

# FIX: all vars local, cap at 100%, guard division by zero
progress_bar() {
  local cur=$1 tot=$2 lbl=${3:-""}
  local w=40 pct fill bar="" local_i

  if [[ "$tot" -le 0 ]]; then
    printf "\r  ${G}[%s]${N} ${W}100%%${N}  ${DIM}%s${N}" "$(printf '█%.0s' $(seq 1 $w))" "$lbl"
    return
  fi

  pct=$(( cur * 100 / tot ))
  [[ $pct -gt 100 ]] && pct=100
  fill=$(( cur * w / tot ))
  [[ $fill -gt $w ]] && fill=$w

  for ((local_i=0; local_i<fill; local_i++));  do bar+="█"; done
  for ((local_i=fill; local_i<w; local_i++));  do bar+="░"; done

  printf "\r  ${G}[%s]${N} ${W}%3d%%${N}  ${DIM}%s${N}" "$bar" "$pct" "$lbl"
}

# ══════════════════════════════════════════════════════════════════
# INPUT VALIDATION
# ══════════════════════════════════════════════════════════════════

# Validate target is a valid domain or IP — block obviously invalid input
validate_target() {
  local t="$1"

  # Strip protocol if user pastes a URL
  t="${t#http://}"; t="${t#https://}"; t="${t%%/*}"

  # Empty check
  [[ -z "$t" ]] && { err "Target cannot be empty"; return 1; }

  # Length sanity
  [[ ${#t} -gt 253 ]] && { err "Target too long (max 253 chars)"; return 1; }

  # Must be valid domain or IP pattern
  local domain_re='^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  local ip_re='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  local ipv6_re='^[0-9a-fA-F:]+$'

  if [[ "$t" =~ $domain_re ]] || [[ "$t" =~ $ip_re ]] || [[ "$t" =~ $ipv6_re ]]; then
    # Validate IP octets if it's an IPv4
    if [[ "$t" =~ $ip_re ]]; then
      local IFS='.'
      read -ra octs <<< "$t"
      for o in "${octs[@]}"; do
        [[ $o -gt 255 ]] && { err "Invalid IP address: $t"; return 1; }
      done
    fi
    echo "$t"   # return sanitized target
    return 0
  fi

  err "Invalid target: '$t' — must be a domain or IP address"
  return 1
}

# ══════════════════════════════════════════════════════════════════
# DISTRO DETECTION
# ══════════════════════════════════════════════════════════════════
DISTRO="" PKG_MANAGER="" PKG_INSTALL="" PKG_UPDATE="" DISTRO_FAMILY=""

detect_distro() {
  header_box "System Detection"

  # Guard: /etc/os-release must exist
  if [[ ! -f /etc/os-release ]]; then
    crit "/etc/os-release not found — cannot detect distro"
    err "Supported: Kali, Parrot, Ubuntu, Debian, Mint, Arch, Manjaro, BlackArch, Fedora, CentOS/RHEL"
    exit 1
  fi

  local os_id="" os_like="" os_name=""
  os_id=$(grep   ^ID=          /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]' || true)
  os_like=$(grep ^ID_LIKE=     /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]' || true)
  os_name=$(grep ^PRETTY_NAME= /etc/os-release | cut -d= -f2 | tr -d '"' || echo "Unknown")

  [[ -z "$os_id" ]] && { crit "Could not read OS ID from /etc/os-release"; exit 1; }

  info "OS detected: ${W}${os_name}${N}"

  case "$os_id" in
    kali|parrot|parrotsec|debian|ubuntu|linuxmint|mint|pop|raspbian)
      DISTRO_FAMILY="debian"
      PKG_MANAGER="apt"; PKG_INSTALL="apt install -y"; PKG_UPDATE="apt update -qq" ;;
    blackarch|arch|manjaro|endeavouros|garuda)
      DISTRO_FAMILY="arch"
      PKG_MANAGER="pacman"; PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy --noconfirm" ;;
    fedora|centos|rhel|rocky|almalinux|ol)
      DISTRO_FAMILY="rhel"
      PKG_MANAGER="dnf"; PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update -q || true" ;;
    opensuse*|sles)
      DISTRO_FAMILY="suse"
      PKG_MANAGER="zypper"; PKG_INSTALL="zypper install -y"; PKG_UPDATE="zypper refresh" ;;
    *)
      # Fallback via ID_LIKE
      if   echo "$os_like" | grep -qi "debian\|ubuntu"; then
        DISTRO_FAMILY="debian"; PKG_MANAGER="apt"
        PKG_INSTALL="apt install -y"; PKG_UPDATE="apt update -qq"
        warn "Unknown distro '$os_id' — using Debian family (apt)"
      elif echo "$os_like" | grep -qi "arch"; then
        DISTRO_FAMILY="arch"; PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy --noconfirm"
        warn "Unknown distro '$os_id' — using Arch family (pacman)"
      elif echo "$os_like" | grep -qi "rhel\|fedora"; then
        DISTRO_FAMILY="rhel"; PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update -q || true"
        warn "Unknown distro '$os_id' — using RHEL family (dnf)"
      else
        crit "Unsupported distro: '$os_id'"
        err  "Supported families: debian · arch · rhel · suse"
        exit 1
      fi ;;
  esac

  DISTRO="$os_id"
  log "Distro  : ${C}${os_name}${N}"
  log "Family  : ${C}${DISTRO_FAMILY}${N}"
  log "Manager : ${C}${PKG_MANAGER}${N}"
}

# ══════════════════════════════════════════════════════════════════
# PACKAGE MAP
# ══════════════════════════════════════════════════════════════════
get_pkg() {
  local tool=$1
  case "$DISTRO_FAMILY" in
    debian) case "$tool" in
      nmap) echo "nmap"       ;; whois)   echo "whois"      ;; dig)  echo "dnsutils"  ;;
      curl) echo "curl"       ;; wget)    echo "wget"        ;; whatweb) echo "whatweb" ;;
      openssl) echo "openssl" ;; tcpdump) echo "tcpdump"    ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__"            ;; *) echo "$tool" ;;
    esac ;;
    rhel) case "$tool" in
      nmap) echo "nmap"       ;; whois)   echo "whois"      ;; dig)  echo "bind-utils" ;;
      curl) echo "curl"       ;; wget)    echo "wget"        ;; whatweb) echo "__gem__" ;;
      openssl) echo "openssl" ;; tcpdump) echo "tcpdump"    ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__"            ;; *) echo "$tool" ;;
    esac ;;
    arch) case "$tool" in
      nmap) echo "nmap"       ;; whois)   echo "whois"      ;; dig)  echo "bind"       ;;
      curl) echo "curl"       ;; wget)    echo "wget"        ;; whatweb) echo "whatweb" ;;
      openssl) echo "openssl" ;; tcpdump) echo "tcpdump"    ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__"            ;; *) echo "$tool" ;;
    esac ;;
    suse) case "$tool" in
      nmap) echo "nmap"       ;; whois)   echo "whois"      ;; dig)  echo "bind-utils" ;;
      curl) echo "curl"       ;; wget)    echo "wget"        ;; openssl) echo "openssl" ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__"            ;; *) echo "$tool" ;;
    esac ;;
  esac
}

declare -A GO_TOOLS=(
  [subfinder]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  [httpx]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
  [nuclei]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  [ffuf]="github.com/ffuf/ffuf/v2@latest"
)

declare -A TOOL_ALT=(
  [subfinder]="amass"
  [httpx]="curl"
  [nuclei]="nikto"
  [ffuf]="gobuster"
  [whatweb]="curl"
)

# ══════════════════════════════════════════════════════════════════
# AUTOFIX ENGINE — 4-step recovery
# ══════════════════════════════════════════════════════════════════
install_go_tool() {
  local tool=$1
  local gopkg="${GO_TOOLS[$tool]:-}"
  [[ -z "$gopkg" ]] && { warn "No Go package defined for $tool"; return 1; }

  if ! command -v go &>/dev/null; then
    fix "Installing Go (required for $tool)..."
    sudo $PKG_INSTALL golang &>/dev/null || { err "Failed to install Go"; return 1; }
  fi

  fix "go install $gopkg..."
  if go install "$gopkg" &>/dev/null; then
    local gopath; gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
    export PATH="$PATH:${gopath}/bin"
    command -v "$tool" &>/dev/null && return 0
  fi
  return 1
}

autofix() {
  local tool=$1
  fix "AUTOFIX: ${W}$tool${N}"
  local pkg; pkg=$(get_pkg "$tool")

  # Step 1 — reinstall
  if [[ "$pkg" == "__go__" ]]; then
    install_go_tool "$tool" && { log "$tool installed via Go"; return 0; }
  elif [[ "$pkg" == "__gem__" ]]; then
    command -v gem &>/dev/null && {
      sudo gem install "$tool" &>/dev/null && { log "$tool installed via gem"; return 0; }
    }
  else
    fix "Reinstalling: $pkg"
    sudo $PKG_INSTALL "$pkg" &>/dev/null && {
      command -v "$tool" &>/dev/null && { log "$tool reinstalled"; return 0; }
    }
  fi

  # Step 2 — fix permissions
  local tp; tp=$(which "$tool" 2>/dev/null || find /usr/bin /usr/local/bin -name "$tool" 2>/dev/null | head -1 || true)
  if [[ -n "$tp" && -f "$tp" ]]; then
    sudo chmod +x "$tp" 2>/dev/null && command -v "$tool" &>/dev/null && {
      log "Permissions fixed: $tp"; return 0
    }
  fi

  # Step 3 — switch to alternative
  local alt="${TOOL_ALT[$tool]:-}"
  if [[ -n "$alt" ]] && command -v "$alt" &>/dev/null; then
    warn "$tool unavailable → using alternative: ${W}$alt${N}"
    echo "$alt" > "$CACHE_DIR/alt_${tool}"
    return 0
  fi

  # Step 4 — distro-specific retry
  fix "Last resort retry..."
  case "$DISTRO_FAMILY" in
    debian)
      sudo apt-get install -y --fix-missing "$pkg" &>/dev/null && \
        command -v "$tool" &>/dev/null && { log "$tool recovered via --fix-missing"; return 0; } ;;
    arch)
      sudo pacman -S --noconfirm --needed "$pkg" &>/dev/null && \
        command -v "$tool" &>/dev/null && { log "$tool recovered via pacman --needed"; return 0; } ;;
    rhel)
      sudo dnf install -y --skip-broken "$pkg" &>/dev/null && \
        command -v "$tool" &>/dev/null && { log "$tool recovered via --skip-broken"; return 0; } ;;
  esac

  err "AUTOFIX exhausted all steps for: $tool"
  return 1
}

check_tool() {
  local tool=$1 required=${2:-false}
  if command -v "$tool" &>/dev/null; then
    log "Found   : ${C}$tool${N}  $(command -v "$tool")"
    return 0
  fi
  warn "Missing : ${Y}$tool${N}"
  if [[ "$required" == "true" ]]; then
    act "Auto-installing required tool: $tool"
    autofix "$tool" || {
      crit "Required tool '$tool' could not be installed — some modules will fail"
    }
  else
    printf "  ${INF} Install optional ${W}%s${N}? [y/N] " "$tool"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]] && autofix "$tool" || info "Skipping optional: $tool"
  fi
}

run_deps() {
  header_box "Dependency Check & Auto-Install"
  info "Running on: ${W}${DISTRO}${N} — Package manager: ${C}${PKG_MANAGER}${N}"

  # Check sudo access before attempting installs
  if ! sudo -n true 2>/dev/null; then
    warn "sudo access not cached — you may be prompted for your password"
  fi

  act "Updating package cache..."
  (sudo $PKG_UPDATE &>/dev/null) &
  local upd_pid=$!
  spinner $upd_pid "Updating ${PKG_MANAGER}..."
  wait $upd_pid 2>/dev/null || warn "Package cache update failed — continuing anyway"
  log "Cache updated"

  echo ""
  info "${W}Required tools:${N}"
  for t in nmap whois dig curl wget openssl; do check_tool "$t" true; done

  echo ""
  info "${W}Optional tools ${DIM}(extend functionality):${N}"
  for t in subfinder httpx whatweb nuclei ffuf; do check_tool "$t" false; done

  echo ""
  log "Dependency check complete"
}

# ══════════════════════════════════════════════════════════════════
# PLUGIN SYSTEM
# ══════════════════════════════════════════════════════════════════
init_dirs() {
  mkdir -p "$RECON_KIT_DIR" "$PLUGINS_DIR" "$CACHE_DIR" || {
    crit "Cannot create recon-kit directories in $RECON_KIT_DIR"
    err  "Check permissions on $HOME"
    exit 1
  }

  [[ ! -f "$CONFIG_FILE" ]] && cat > "$CONFIG_FILE" << 'CFG'
# recon-kit config — edit as needed
THREADS=10
TIMEOUT=30
AUTO_INSTALL=true
AUTO_FIX=true
USER_AGENT="recon-kit/2.1.1 (github.com/wavegxz-design/recon-kit)"
CFG

  # Source update module if present alongside this script
  local update_script="${BASH_SOURCE[0]%/*}/update.sh"
  [[ -f "$update_script" ]] && source "$update_script" 2>/dev/null || true
}

load_plugins() {
  local count=0
  compgen -G "$PLUGINS_DIR/*.sh" &>/dev/null || return 0
  for p in "$PLUGINS_DIR"/*.sh; do
    [[ -f "$p" ]] || continue
    # Validate plugin syntax before sourcing
    if bash -n "$p" 2>/dev/null; then
      # shellcheck source=/dev/null
      source "$p" 2>/dev/null && {
        count=$((count+1))
        info "Plugin: ${C}$(basename "$p")${N}"
      } || warn "Plugin failed to load: $(basename "$p")"
    else
      warn "Plugin has syntax errors — skipped: $(basename "$p")"
    fi
  done
  [[ $count -gt 0 ]] && log "$count plugin(s) loaded"
}

list_plugins() {
  header_box "Installed Plugins"
  compgen -G "$PLUGINS_DIR/*.sh" &>/dev/null || {
    info "No plugins installed."
    info "Drop .sh files into: ${C}$PLUGINS_DIR${N}"
    info "Site: ${Y}${SITE}${N}"
    return
  }
  for p in "$PLUGINS_DIR"/*.sh; do
    [[ -f "$p" ]] || continue
    local name; name=$(grep "^# PLUGIN:" "$p" 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || basename "$p")
    local desc; desc=$(grep "^# DESC:"   "$p" 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo "No description")
    local author; author=$(grep "^# AUTHOR:" "$p" 2>/dev/null | cut -d: -f2 | sed 's/^ *//' || echo "unknown")
    printf "  ${G}→${N} ${W}%-20s${N} ${DIM}%s${N}  ${C}[%s]${N}\n" "$name" "$desc" "$author"
  done
}

# ══════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════

# FIX: extract root domain safely — handles subdomains, IPs, protocols
get_root_domain() {
  local host="$1"
  # Strip protocol
  host="${host#http://}"; host="${host#https://}"; host="${host%%/*}"
  # If it's an IP, return as-is
  if [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$host"; return
  fi
  # Extract root domain (last two labels)
  echo "$host" | awk -F. '{
    n = NF
    if (n >= 2) print $(n-1)"."$n
    else print $0
  }'
}

setup_output() {
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local safe; safe=$(echo "$TARGET" | tr '/:.' '_' | tr -cd '[:alnum:]_-')
  OUTPUT_DIR="${RECON_KIT_DIR}/output/${safe}_${ts}"

  mkdir -p "$OUTPUT_DIR"/{nmap,dns,whois,subdomains,web,headers,cert,plugins} || {
    crit "Cannot create output directory: $OUTPUT_DIR"
    exit 1
  }

  LOG_FILE="$OUTPUT_DIR/recon.log"
  {
    echo "# recon-kit v${VERSION}"
    echo "# Target : $TARGET"
    echo "# Date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# Distro : $DISTRO"
    echo "# UID    : $(id -un) ($(id -u))"
    echo "# Site   : $SITE"
    echo "# Author : krypthane | wavegxz-design"
  } > "$LOG_FILE"

  info "Output → ${W}$OUTPUT_DIR${N}"
}

# ══════════════════════════════════════════════════════════════════
# NETWORK HELPERS
# ══════════════════════════════════════════════════════════════════

# Check basic connectivity before running modules
check_connectivity() {
  act "Checking network connectivity..."
  if curl -sf --max-time 5 https://1.1.1.1 &>/dev/null \
    || curl -sf --max-time 5 https://8.8.8.8 &>/dev/null; then
    log "Network: ${G}online${N}"
    return 0
  fi
  warn "Network connectivity check failed — results may be incomplete"
  return 1
}

# Resolve target to confirm it's reachable
resolve_target() {
  local t="$1"
  # Skip resolution for IPs
  if [[ "$t" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    log "Target is IP — skipping DNS resolution"
    return 0
  fi
  local resolved; resolved=$(dig +short A "$t" 2>/dev/null | head -1 || true)
  if [[ -n "$resolved" ]]; then
    log "Target resolves to: ${C}$resolved${N}"
    return 0
  fi
  warn "Target '$t' does not resolve — it may be offline or mistyped"
  printf "  ${INF} Continue anyway? [y/N] "
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]] || { info "Aborted by user"; exit 0; }
}

# ══════════════════════════════════════════════════════════════════
# MODULE: WHOIS
# ══════════════════════════════════════════════════════════════════
module_whois() {
  section "WHOIS — $TARGET"
  local out="$OUTPUT_DIR/whois/whois.txt"

  # FIX: always query root domain — subdomains return empty whois
  local root_domain; root_domain=$(get_root_domain "$TARGET")
  [[ "$root_domain" != "$TARGET" ]] && \
    info "Subdomain detected → querying root domain: ${W}$root_domain${N}"

  command -v whois &>/dev/null || autofix whois
  command -v whois &>/dev/null || { err "whois unavailable — skipping module"; return; }

  # Timeout the whois call
  local raw
  raw=$(timeout 20 whois "$root_domain" 2>/dev/null) || {
    warn "whois timed out or returned error for $root_domain"
    echo "whois timeout or error" > "$out"
    return
  }
  echo "$raw" > "$out"

  # FIX: safe sed parsing — no xargs, handles special chars
  local registrar created expires ns

  registrar=$(echo "$raw" | grep -i 'registrar:' | head -1 \
    | sed 's/.*Registrar:[[:space:]]*//' | tr -d '\r\n' || echo "N/A")

  created=$(echo "$raw" | grep -iE 'creation date:|created:' | head -1 \
    | sed 's/.*created[^:]*:[[:space:]]*//' | tr -d '\r\n' | cut -c1-30 || echo "N/A")

  expires=$(echo "$raw" | grep -iE 'expir' | head -1 \
    | sed 's/[^:]*:[[:space:]]*//' | tr -d '\r\n' | cut -c1-30 || echo "N/A")

  # FIX: collapse multiline NS into single line
  ns=$(echo "$raw" | grep -iE 'name server:|nserver:' \
    | sed 's/[^:]*:[[:space:]]*//' | tr -d '\r' | tr '\n' ' ' | sed 's/ $//' | head -c 120 || echo "N/A")

  log "Registrar : ${C}${registrar:-N/A}${N}"
  log "Created   : ${C}${created:-N/A}${N}"
  log "Expires   : ${C}${expires:-N/A}${N}"
  log "NS        : ${C}${ns:-N/A}${N}"
  info "Full → $out"
}

# ══════════════════════════════════════════════════════════════════
# MODULE: DNS
# ══════════════════════════════════════════════════════════════════
module_dns() {
  section "DNS Enumeration — $TARGET"
  local out="$OUTPUT_DIR/dns"

  command -v dig &>/dev/null || autofix dig
  command -v dig &>/dev/null || { err "dig unavailable — skipping DNS module"; return; }

  local types=("A" "AAAA" "MX" "NS" "TXT" "SOA" "CNAME" "SRV" "CAA")
  local found_any=false

  for rtype in "${types[@]}"; do
    local res; res=$(timeout 10 dig +short "$rtype" "$TARGET" 2>/dev/null || true)
    if [[ -n "$res" ]]; then
      found_any=true
      printf "%-8s %s\n" "[$rtype]" "$res" >> "$out/records.txt"
      # FIX: collapse multiline into single log line
      local res_line; res_line=$(echo "$res" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
      log "$(printf '%-6s' "$rtype"): ${C}${res_line}${N}"
    fi
  done

  $found_any || warn "No DNS records found — target may not exist or DNS is blocked"

  # DMARC (special TXT prefix)
  local dmarc; dmarc=$(timeout 10 dig +short TXT "_dmarc.$TARGET" 2>/dev/null || true)
  [[ -n "$dmarc" ]] && {
    echo "[DMARC]  $dmarc" >> "$out/records.txt"
    log "DMARC : ${C}$(echo "$dmarc" | tr '\n' ' ')${N}"
  }

  # Zone transfer
  info "Zone transfer attempt (AXFR)..."
  local ns; ns=$(timeout 10 dig +short NS "$TARGET" 2>/dev/null | head -1 | tr -d '\n\r' || true)
  if [[ -n "$ns" ]]; then
    timeout 15 dig AXFR "$TARGET" "@$ns" > "$out/axfr.txt" 2>/dev/null || true
    local lines; lines=$(wc -l < "$out/axfr.txt" 2>/dev/null || echo 0)
    if [[ $lines -gt 5 ]]; then
      crit "Zone transfer SUCCEEDED on $ns → $out/axfr.txt"
      warn "This is a critical DNS misconfiguration — all records are exposed"
    else
      info "Zone transfer blocked (expected behavior)"
      rm -f "$out/axfr.txt"
    fi
  else
    info "No NS record found — zone transfer skipped"
  fi
}

# ══════════════════════════════════════════════════════════════════
# MODULE: SUBDOMAINS
# ══════════════════════════════════════════════════════════════════
module_subdomains() {
  section "Subdomain Enumeration — $TARGET"
  local out="$OUTPUT_DIR/subdomains"
  local sub_i=0

  # Passive — subfinder
  if command -v subfinder &>/dev/null; then
    act "Running subfinder (passive)..."
    timeout 120 subfinder -d "$TARGET" -silent -o "$out/subfinder.txt" 2>/dev/null &
    local sf_pid=$!
    spinner "$sf_pid" "subfinder scanning $TARGET..."
    wait $sf_pid 2>/dev/null || true
    local sf_count; sf_count=$(wc -l < "$out/subfinder.txt" 2>/dev/null || echo 0)
    log "subfinder: ${G}${sf_count}${N} found"
  else
    warn "subfinder not installed — go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    touch "$out/subfinder.txt"
  fi

  # FIX: external wordlist support via -w flag
  # Usage: ./recon-kit.sh -t target.com -w /path/to/subdomains.txt
  local -a subs_to_check=()
  if [[ -n "${WORDLIST:-}" && -f "$WORDLIST" ]]; then
    act "Loading wordlist: $WORDLIST"
    while IFS= read -r _wl_line; do
      [[ -n "$_wl_line" && "${_wl_line:0:1}" != "#" ]] && subs_to_check+=("$_wl_line")
    done < "$WORDLIST"
    info "Wordlist: ${G}${#subs_to_check[@]}${N} entries from $WORDLIST"
  else
    [[ -n "${WORDLIST:-}" ]] && warn "Wordlist not found: $WORDLIST — using built-in list"
    subs_to_check=(
      "www" "mail" "ftp" "admin" "api" "dev" "staging" "vpn" "remote"
      "test" "portal" "dashboard" "cdn" "blog" "shop" "app" "mobile" "beta"
      "backup" "git" "jenkins" "grafana" "kibana" "jira" "wiki" "smtp"
      "ns1" "ns2" "mx" "relay" "webmail" "cpanel" "autodiscover"
      "support" "status" "cloud" "login" "secure" "auth" "sso"
      "m" "www2" "new" "old" "demo" "preprod" "prod" "uat" "qa"
      "api2" "v1" "v2" "docs" "help" "forum" "community" "intranet"
      "internal" "db" "redis" "monitor" "metrics" "logs" "elk"
      "assets" "static" "media" "img" "files" "upload" "download"
      "billing" "crm" "ldap" "dc1" "dc2" "proxy" "gateway" "fw"
    )
    info "Built-in wordlist: ${#subs_to_check[@]} subdomains"
    info "Tip: ./recon-kit.sh -t $TARGET -w subdomains.txt for custom wordlist"
  fi

  act "Brute forcing ${#subs_to_check[@]} subdomains..."
  local total=${#subs_to_check[@]} found=0

  for sub in "${subs_to_check[@]}"; do
    sub_i=$((sub_i + 1))
    progress_bar "$sub_i" "$total" "Checking ${sub}.${TARGET}"
    local res; res=$(timeout 5 dig +short A "${sub}.${TARGET}" 2>/dev/null || true)
    if [[ -n "$res" ]]; then
      echo "${sub}.${TARGET} → $res" >> "$out/bruteforce.txt"
      echo -e "  ${G}[FOUND]${N}  ${G}${sub}.${TARGET}${N}  →  ${C}${res}${N}"
      found=$((found + 1))
    fi
  done
  echo ""
  log "Brute force: ${G}${found}${N} active subdomains found"

  # Merge + deduplicate all sources
  cat "$out"/*.txt 2>/dev/null \
    | grep -oP "[\w\-\.]+\.${TARGET//./\\.}" 2>/dev/null \
    | sort -u > "$out/all.txt" || true

  local total_subs; total_subs=$(wc -l < "$out/all.txt" 2>/dev/null || echo 0)
  log "Total unique subdomains: ${G}${total_subs}${N} → $out/all.txt"
}

# ══════════════════════════════════════════════════════════════════
# MODULE: PORT SCAN
# ══════════════════════════════════════════════════════════════════
module_portscan() {
  section "Port Scan — $TARGET"
  local out="$OUTPUT_DIR/nmap"

  command -v nmap &>/dev/null || autofix nmap
  command -v nmap &>/dev/null || { err "nmap unavailable — skipping port scan"; return; }

  # Quick scan — top 1000 ports
  # FIX: was &>/dev/null — user saw nothing. Now shows live port hits.
  act "Quick scan — top 1000 ports (live output)..."
  local nmap_rc=0
  echo ""

  # Run nmap with live output, also save to file
  timeout 300 nmap -sV --open -T4 \
    -oN "$out/quick.txt" \
    -oX "$out/quick.xml" \
    "$TARGET" 2>/dev/null | while IFS= read -r line; do
      # Show open port lines in green, section headers dimmed
      if [[ "$line" =~ ^[0-9]+.*open ]]; then
        echo -e "  ${G}[OPEN]${N}  $line" | tee -a "$LOG_FILE"
      elif [[ "$line" =~ ^Nmap|^PORT|^Not ]]; then
        echo -e "  ${DIM}$line${N}"
      fi
    done
  nmap_rc=${PIPESTATUS[0]}

  case $nmap_rc in
    0)   : ;;
    1)   warn "nmap: no open ports found or host offline" ;;
    3)   warn "nmap: host seems down — try adding -Pn flag" ;;
    124) warn "nmap quick scan timed out after 300s" ;;
    *)   warn "nmap returned code $nmap_rc — results may be partial" ;;
  esac

  # Full TCP scan — background, silent (takes too long for live output)
  act "Full TCP scan started in background (all 65535 ports)..."
  timeout 3600 nmap -sV -p- --open -T3 -oN "$out/full.txt" "$TARGET" >/dev/null 2>&1 &
  log "Full scan PID $! → results will be in $out/full.txt when complete"

  # UDP — root only
  if [[ $EUID -eq 0 ]]; then
    act "UDP scan — top 100..."
    timeout 600 nmap -sU --top-ports 100 -T4 -oN "$out/udp.txt" "$TARGET" &>/dev/null &
    log "UDP scan PID $! → $out/udp.txt"
  else
    warn "UDP scan requires root — run with sudo to enable"
  fi

  # Display open ports
  echo ""
  info "${W}Open ports (quick scan):${N}"
  local open_count=0
  if [[ -f "$out/quick.txt" ]]; then
    while IFS= read -r line; do
      if [[ "$line" =~ ^[0-9]+.*open ]]; then
        echo -e "  ${G}→${N} $line" | tee -a "$LOG_FILE"
        open_count=$((open_count + 1))
      fi
    done < "$out/quick.txt"
  fi
  [[ $open_count -eq 0 ]] && warn "No open ports found — target may be offline or firewalled"
}

# ══════════════════════════════════════════════════════════════════
# MODULE: WEB RECON
# ══════════════════════════════════════════════════════════════════
module_web() {
  section "Web Reconnaissance — $TARGET"
  local out="$OUTPUT_DIR/web"
  local hout="$OUTPUT_DIR/headers"
  local url_https="https://${TARGET}"
  local url_http="http://${TARGET}"

  command -v curl &>/dev/null || { err "curl unavailable — skipping web module"; return; }

  # Grab headers — both HTTP and HTTPS
  act "Grabbing HTTP/S headers..."
  timeout 20 curl -sIL --max-time 15 \
    -A "Mozilla/5.0 recon-kit/${VERSION}" \
    "$url_https" > "$hout/https.txt" 2>/dev/null || true

  timeout 20 curl -sIL --max-time 15 \
    -A "Mozilla/5.0 recon-kit/${VERSION}" \
    "$url_http" > "$hout/http.txt" 2>/dev/null || true

  # Detect HTTP → HTTPS redirect
  local http_code; http_code=$(curl -so /dev/null -w "%{http_code}" \
    --max-time 10 "$url_http" 2>/dev/null || echo "000")
  if [[ "$http_code" =~ ^30[0-9]$ ]]; then
    info "HTTP redirects to HTTPS ${G}[$http_code]${N}"
  elif [[ "$http_code" == "000" ]]; then
    warn "HTTP appears unreachable — target may be HTTPS only"
  fi

  # Security headers audit
  info "${W}Security headers audit:${N}"
  local sec_headers=(
    "Strict-Transport-Security"
    "Content-Security-Policy"
    "X-Frame-Options"
    "X-Content-Type-Options"
    "Referrer-Policy"
    "Permissions-Policy"
    "X-XSS-Protection"
    "Cross-Origin-Opener-Policy"
  )
  local present=0 missing=0
  local audit_file="$hout/security_audit.txt"
  echo "# Security Headers Audit — $TARGET — $(date)" > "$audit_file"

  for h in "${sec_headers[@]}"; do
    if grep -qi "^${h}:" "$hout/https.txt" 2>/dev/null; then
      echo -e "  ${G}[PRESENT]${N} $h" | tee -a "$LOG_FILE"
      echo "[PRESENT] $h" >> "$audit_file"
      ((present++)) || true
    else
      echo -e "  ${R}[MISSING]${N} $h" | tee -a "$LOG_FILE"
      echo "[MISSING] $h" >> "$audit_file"
      ((missing++)) || true
      WARNINGS+=("Missing security header: $h")
    fi
  done
  log "Headers: ${G}${present} present${N} / ${R}${missing} missing${N}"

  # Tech detection via WhatWeb
  if command -v whatweb &>/dev/null; then
    act "WhatWeb technology detection..."
    timeout 30 whatweb -a 3 "$url_https" > "$out/whatweb.txt" 2>/dev/null || true
    log "Tech fingerprint → $out/whatweb.txt"
  else
    info "whatweb not available — skipping tech detection"
  fi

  # Common file discovery
  act "Common files check..."
  local interesting_files=(
    "robots.txt" "sitemap.xml" ".well-known/security.txt"
    "crossdomain.xml" "humans.txt" ".htaccess"
    "phpinfo.php" "info.php" "test.php" "wp-login.php"
    ".git/HEAD" ".env" "config.php" "backup.zip"
  )
  local disco_file="$out/discovered_files.txt"

  for p in "${interesting_files[@]}"; do
    local code; code=$(timeout 10 curl -so /dev/null \
      -w "%{http_code}" \
      -A "Mozilla/5.0 recon-kit/${VERSION}" \
      "${url_https}/${p}" 2>/dev/null || echo "000")

    case $code in
      200)
        timeout 10 curl -s -A "Mozilla/5.0 recon-kit/${VERSION}" \
          "${url_https}/${p}" > "$out/${p//\//_}" 2>/dev/null || true
        echo "[200] /${p}" >> "$disco_file"
        log "Found: ${G}/${p}${N} [$code]"
        # Critical findings
        case "$p" in
          ".git/HEAD"|".env"|"phpinfo.php"|"info.php"|"backup.zip")
            crit "Sensitive file exposed: /${p}" ;;
        esac
        ;;
      301|302)
        echo "[${code}] /${p} (redirect)" >> "$disco_file" ;;
      403)
        echo "[403] /${p} (forbidden — exists)" >> "$disco_file"
        info "Exists but forbidden: /${p}" ;;
    esac
  done

  # Probe live subdomains with httpx
  if command -v httpx &>/dev/null && \
     [[ -f "$OUTPUT_DIR/subdomains/all.txt" ]] && \
     [[ -s "$OUTPUT_DIR/subdomains/all.txt" ]]; then
    act "Probing live subdomains with httpx..."
    timeout 60 httpx \
      -l "$OUTPUT_DIR/subdomains/all.txt" \
      -silent -status-code -title -follow-redirects \
      > "$out/live_hosts.txt" 2>/dev/null || true
    local live_count; live_count=$(wc -l < "$out/live_hosts.txt" 2>/dev/null || echo 0)
    log "Live hosts: ${G}${live_count}${N} → $out/live_hosts.txt"
  fi
}

# ══════════════════════════════════════════════════════════════════
# MODULE: SSL/TLS CERT
# ══════════════════════════════════════════════════════════════════
module_cert() {
  section "SSL/TLS Certificate — $TARGET"
  local out="$OUTPUT_DIR/cert/cert.txt"

  command -v openssl &>/dev/null || autofix openssl
  command -v openssl &>/dev/null || { err "openssl unavailable — skipping cert module"; return; }

  # Fetch cert with timeout
  local cert_raw
  cert_raw=$(echo | timeout 15 openssl s_client \
    -connect "${TARGET}:443" \
    -servername "$TARGET" \
    -tls1_2 \
    2>/dev/null) || true

  if [[ -z "$cert_raw" ]]; then
    warn "Could not connect to ${TARGET}:443 — trying without SNI..."
    cert_raw=$(echo | timeout 15 openssl s_client \
      -connect "${TARGET}:443" 2>/dev/null) || true
  fi

  if [[ -z "$cert_raw" ]]; then
    warn "No TLS certificate found — target may not support HTTPS"
    return
  fi

  # Parse cert to text
  echo "$cert_raw" | openssl x509 -noout -text > "$out" 2>/dev/null || {
    warn "Could not parse certificate data"
    return
  }

  # FIX: use sed — safe with special chars, no xargs issues
  local subject issuer expires sans

  subject=$(grep 'Subject:' "$out" 2>/dev/null | head -1 \
    | sed 's/[[:space:]]*Subject:[[:space:]]*//' | tr -d '\r\n')

  issuer=$(grep 'Issuer:' "$out" 2>/dev/null | head -1 \
    | sed 's/[[:space:]]*Issuer:[[:space:]]*//' | tr -d '\r\n')

  expires=$(grep 'Not After' "$out" 2>/dev/null | head -1 \
    | sed 's/.*Not After[[:space:]]*:[[:space:]]*//' | tr -d '\r\n')

  # FIX: correct SANs — get line with DNS: after Subject Alternative Name header
  sans=$(awk '/Subject Alternative Name/{getline; print}' "$out" 2>/dev/null \
    | sed 's/^[[:space:]]*//' | tr -d '\r\n' \
    | grep -o 'DNS:[^,]*' | tr '\n' ' ' | head -c 200 || echo "N/A")

  log "Subject : ${C}${subject:-N/A}${N}"
  log "Issuer  : ${C}${issuer:-N/A}${N}"
  log "Expires : ${C}${expires:-N/A}${N}"
  log "SANs    : ${C}${sans:-N/A}${N}"

  # Expiry countdown with warning levels
  if [[ -n "$expires" ]]; then
    local exp_e; exp_e=$(date -d "$expires" +%s 2>/dev/null || true)
    if [[ -n "$exp_e" ]]; then
      local now_e; now_e=$(date +%s)
      local days=$(( (exp_e - now_e) / 86400 ))
      if   [[ $days -lt 0 ]];   then crit "Certificate EXPIRED ${R}${days#-} days ago!${N}"
      elif [[ $days -lt 7 ]];   then crit "Certificate expires in ${R}${days} days!${N}"
      elif [[ $days -lt 30 ]];  then warn "Certificate expires in ${Y}${days} days${N}"
      elif [[ $days -lt 90 ]];  then info "Certificate valid for ${Y}${days} more days${N}"
      else                           log  "Certificate valid for ${G}${days} more days${N}"
      fi
    fi
  fi

  # Check cipher strength
  act "Checking TLS cipher support..."
  local weak_found=false
  for proto in "ssl2" "ssl3" "tls1" "tls1_1"; do
    if echo | timeout 5 openssl s_client \
      -connect "${TARGET}:443" \
      -"${proto/tls/tls}" 2>&1 | grep -q "Protocol  :"; then
      crit "Weak protocol supported: ${proto^^}"
      weak_found=true
    fi
  done
  $weak_found || log "No weak TLS protocols detected ${G}[good]${N}"
}

# ══════════════════════════════════════════════════════════════════
# REPORT GENERATOR
# ══════════════════════════════════════════════════════════════════
generate_report() {
  local end_t; end_t=$(date +%s)
  local elapsed=$(( end_t - START_TIME ))

  # Safe counters
  local open_ports subs miss_h crit_count
  open_ports=$(grep -cE "open$|open[[:space:]]" "$OUTPUT_DIR/nmap/quick.txt" 2>/dev/null || echo 0)
  subs=$(wc -l < "$OUTPUT_DIR/subdomains/all.txt" 2>/dev/null || echo 0)
  miss_h=$(grep -c "\[MISSING\]" "$OUTPUT_DIR/headers/security_audit.txt" 2>/dev/null || echo 0)
  crit_count=${#ERRORS[@]}

  local report="$OUTPUT_DIR/REPORT.md"

  cat > "$report" << REPORTEOF
# recon-kit Report — ${TARGET}

| Field      | Value |
|------------|-------|
| Target     | ${TARGET} |
| Date       | $(date '+%Y-%m-%d %H:%M:%S') |
| Duration   | ${elapsed}s |
| Distro     | ${DISTRO} |
| Operator   | krypthane \| wavegxz-design |
| Site       | ${SITE} |

## Summary

| Metric               | Result |
|----------------------|--------|
| Open ports (quick)   | ${open_ports} |
| Subdomains found     | ${subs} |
| Missing sec headers  | ${miss_h} |
| Modules run          | ${#MODULES[@]} |
| Errors / criticals   | ${crit_count} |

## Modules Run
$(for m in "${MODULES[@]}"; do echo "- $m"; done)

## Errors & Criticals
$(if [[ ${#ERRORS[@]} -eq 0 ]]; then
  echo "- None"
else
  for e in "${ERRORS[@]}"; do echo "- $e"; done
fi)

## Warnings
$(if [[ ${#WARNINGS[@]} -eq 0 ]]; then
  echo "- None"
else
  for w in "${WARNINGS[@]}"; do echo "- $w"; done
fi)

## Output Files
$(find "$OUTPUT_DIR" -type f | sort | sed "s|$OUTPUT_DIR/||" | sed 's/^/- /')

---
*recon-kit v${VERSION} — github.com/wavegxz-design/recon-kit*
*${SITE}*
*Authorized use only.*
REPORTEOF

  # Final summary to terminal
  echo ""
  sep_full
  echo -e "  ${W}${BOLD}SCAN COMPLETE${N}"
  sep
  printf "  ${INF} %-24s ${G}%s${N}\n"  "Target:"          "$TARGET"
  printf "  ${INF} %-24s ${C}%ss${N}\n" "Duration:"         "$elapsed"
  printf "  ${INF} %-24s ${G}%s${N}\n"  "Open ports:"       "$open_ports"
  printf "  ${INF} %-24s ${G}%s${N}\n"  "Subdomains:"       "$subs"
  printf "  ${INF} %-24s ${R}%s${N}\n"  "Missing headers:"  "$miss_h"
  printf "  ${INF} %-24s ${R}%s${N}\n"  "Errors/Criticals:" "$crit_count"
  printf "  ${INF} %-24s ${Y}%s${N}\n"  "Output:"           "$OUTPUT_DIR"
  printf "  ${INF} %-24s ${Y}%s${N}\n"  "Report:"           "$report"
  sep_full
  echo ""

  # Print errors summary if any
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "  ${R}${BOLD}Issues found:${N}"
    for e in "${ERRORS[@]}"; do echo -e "  ${ERR} $e"; done
    echo ""
  fi
}

# ══════════════════════════════════════════════════════════════════
# MENU
# ══════════════════════════════════════════════════════════════════
show_menu() {
  echo ""
  echo -e "  ${W}${BOLD}SELECT MODULES${N}"
  sep
  echo -e "  ${C}1${N}) ${W}All modules${N}       ${DIM}— Full recon suite${N}"
  echo -e "  ${C}2${N}) ${W}WHOIS${N}             ${DIM}— Domain registration info${N}"
  echo -e "  ${C}3${N}) ${W}DNS${N}               ${DIM}— Records + zone transfer${N}"
  echo -e "  ${C}4${N}) ${W}Subdomains${N}        ${DIM}— Discovery + brute force${N}"
  echo -e "  ${C}5${N}) ${W}Port Scan${N}         ${DIM}— Nmap quick + full + UDP${N}"
  echo -e "  ${C}6${N}) ${W}Web Recon${N}         ${DIM}— Headers, tech, files${N}"
  echo -e "  ${C}7${N}) ${W}SSL/TLS Cert${N}      ${DIM}— Certificate analysis${N}"
  echo -e "  ${C}8${N}) ${W}Custom${N}            ${DIM}— Pick your modules${N}"
  echo -e "  ${C}p${N}) ${W}Plugins${N}           ${DIM}— List installed plugins${N}"
  echo -e "  ${C}q${N}) ${W}Quit${N}"
  sep
  printf "  ${G}[>]${N} Choice: "
  read -r choice

  case $choice in
    1) MODULES=("whois" "dns" "subdomains" "portscan" "web" "cert") ;;
    2) MODULES=("whois") ;;
    3) MODULES=("dns") ;;
    4) MODULES=("subdomains") ;;
    5) MODULES=("portscan") ;;
    6) MODULES=("web") ;;
    7) MODULES=("cert") ;;
    8)
      printf "  ${G}[>]${N} Modules ${DIM}(whois,dns,subdomains,portscan,web,cert)${N}: "
      read -r custom
      IFS=',' read -ra MODULES <<< "$custom"
      ;;
    p) list_plugins; exit 0 ;;
    q) echo -e "\n  ${DIM}Bye.${N}\n"; exit 0 ;;
    *) err "Invalid option: '$choice'"; exit 1 ;;
  esac
}

usage() {
  echo -e "${W}Usage:${N} $0 -t <target> [options]"
  echo -e ""
  echo -e "${W}Options:${N}"
  echo -e "  -t <target>   Domain or IP to scan"
  echo -e "  -m <modules>  Comma-separated: all|whois,dns,subdomains,portscan,web,cert"
  echo -e "  -w <wordlist> Path to subdomain wordlist (default: built-in 80-entry list)"
  echo -e "  -p            List installed plugins"
  echo -e "  -h            This help"
  echo -e "  --update      Check and apply latest update"
  echo -e "  --check       Check for update without installing"
  echo -e "  --rollback    Restore a previous version from backup"
  echo -e ""
  echo -e "${W}Examples:${N}"
  echo -e "  $0 -t example.com -m all"
  echo -e "  $0 -t example.com -m whois,dns,portscan"
  echo -e "  sudo $0 -t example.com -m all   ${DIM}# enables UDP scan${N}"
  echo -e ""
  echo -e "${DIM}  ${SITE}${N}"
  echo -e "${R}  Authorized targets only.${N}"
}

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════
main() {
  init_dirs
  banner

  # Auto-check update silently (non-blocking, once per 24h)
  declare -f auto_check_update &>/dev/null && auto_check_update "$VERSION" || true

  # Handle special flags before getopts
  case "${1:-}" in
    --update)
      declare -f run_update &>/dev/null \
        && run_update "$VERSION" \
        || echo "update.sh not found — get it at github.com/wavegxz-design/recon-kit"
      exit 0 ;;
    --check)
      declare -f fetch_latest_version &>/dev/null \
        && { latest=$(fetch_latest_version); info "Latest: ${W}${latest}${N} / Current: ${W}${VERSION}${N}"; } \
        || echo "update.sh not found"
      exit 0 ;;
    --rollback)
      declare -f run_rollback &>/dev/null \
        && run_rollback \
        || echo "update.sh not found"
      exit 0 ;;
  esac

  # Parse flags
  while getopts "t:m:ph" opt; do
    case $opt in
      t) TARGET="$OPTARG" ;;
      m) IFS=',' read -ra MODULES <<< "$OPTARG" ;;
      p) list_plugins; exit 0 ;;
      h) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
  done

  # Target input & validation
  if [[ -z "$TARGET" ]]; then
    printf "  ${G}[>]${N} Target domain or IP: "
    read -r TARGET
  fi

  # Sanitize and validate
  local clean_target; clean_target=$(validate_target "$TARGET") || exit 1
  TARGET="$clean_target"

  detect_distro
  setup_output
  check_connectivity
  resolve_target "$TARGET"
  run_deps
  load_plugins

  # Module selection
  [[ ${#MODULES[@]} -eq 0 ]] && show_menu
  [[ "${MODULES[*]}" == *"all"* ]] && \
    MODULES=("whois" "dns" "subdomains" "portscan" "web" "cert")

  # Validate module names
  local valid_mods=("whois" "dns" "subdomains" "portscan" "web" "cert")
  for m in "${MODULES[@]}"; do
    local is_valid=false
    for v in "${valid_mods[@]}"; do [[ "$m" == "$v" ]] && { is_valid=true; break; }; done
    # Also allow plugin modules
    declare -f "plugin_${m}" &>/dev/null && is_valid=true
    $is_valid || warn "Unknown module '$m' — will be skipped if no plugin handles it"
  done

  sep_full
  info "Target  : ${W}$TARGET${N}"
  info "Modules : ${C}${MODULES[*]}${N}"
  info "Output  : ${Y}$OUTPUT_DIR${N}"
  sep_full

  local mod_total=${#MODULES[@]} mod_cur=0
  for module in "${MODULES[@]}"; do
    mod_cur=$((mod_cur + 1))
    progress_bar "$mod_cur" "$mod_total" "Running: $module"
    echo ""

    case $module in
      whois)      module_whois      ;;
      dns)        module_dns        ;;
      subdomains) module_subdomains ;;
      portscan)   module_portscan   ;;
      web)        module_web        ;;
      cert)       module_cert       ;;
      *)
        if declare -f "plugin_${module}" &>/dev/null; then
          "plugin_${module}"
        else
          warn "Unknown module: '$module' — skipping"
        fi
        ;;
    esac
  done

  generate_report
}

main "$@"
