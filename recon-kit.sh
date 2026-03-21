#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              RECON-KIT v2.0 — Reconnaissance Toolkit        ║
# ║         Author  : krypthane | wavegxz-design                ║
# ║         GitHub  : github.com/wavegxz-design/recon-kit       ║
# ║         License : MIT                                        ║
# ║                                                              ║
# ║   USE ONLY ON SYSTEMS YOU OWN OR HAVE WRITTEN PERMISSION.   ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── VERSION ─────────────────────────────────────────────────────
VERSION="2.0.0"
RECON_KIT_DIR="$HOME/.recon-kit"
PLUGINS_DIR="$RECON_KIT_DIR/plugins"
CACHE_DIR="$RECON_KIT_DIR/cache"
CONFIG_FILE="$RECON_KIT_DIR/config"

# ── COLORS ──────────────────────────────────────────────────────
R='\033[0;31m'  G='\033[0;32m'  Y='\033[1;33m'
B='\033[0;34m'  C='\033[0;36m'  M='\033[0;35m'
W='\033[1;37m'  DIM='\033[2m'   BOLD='\033[1m'  N='\033[0m'

OK="${G}[✔]${N}"   ERR="${R}[✘]${N}"  INF="${C}[*]${N}"
WRN="${Y}[!]${N}"  ACT="${M}[→]${N}"  FIX="${B}[⚙]${N}"

# ══════════════════════════════════════════════════════════════════
# UI
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
  echo -e "${N}  ${W}v${VERSION}${N} ${DIM}|${N} ${C}krypthane${N} ${DIM}|${N} ${Y}github.com/wavegxz-design/recon-kit${N}"
  echo -e "  ${DIM}Modular Recon Toolkit — For authorized penetration testing only${N}"
  echo -e "  ${R}[!] Unauthorized use is illegal. You are responsible for your actions.${N}"
  sep_full
}

sep_full() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"; }
sep()      { echo -e "${DIM}──────────────────────────────────────────────────────────────${N}"; }

log()     { echo -e " ${OK} ${W}$*${N}"    | tee -a "$LOG_FILE"; }
info()    { echo -e " ${INF} $*"           | tee -a "$LOG_FILE"; }
warn()    { echo -e " ${WRN} ${Y}$*${N}"   | tee -a "$LOG_FILE"; }
err()     { echo -e " ${ERR} ${R}$*${N}"   | tee -a "$LOG_FILE"; }
act()     { echo -e " ${ACT} ${C}$*${N}"   | tee -a "$LOG_FILE"; }
fix()     { echo -e " ${FIX} ${B}$*${N}"   | tee -a "$LOG_FILE"; }

section() {
  echo "" | tee -a "$LOG_FILE"
  echo -e " ${M}┌─────────────────────────────────────────────┐${N}" | tee -a "$LOG_FILE"
  echo -e " ${M}│${N}  ${W}${BOLD}$*${N}" | tee -a "$LOG_FILE"
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
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${C}${spin:i++%${#spin}:1}${N}  ${DIM}%s${N}" "$msg"
    sleep 0.08
  done
  printf "\r%*s\r" 60 ""
}

progress_bar() {
  local cur=$1 tot=$2 lbl=${3:-""}
  local w=40
  local pct=$(( cur * 100 / tot ))
  local fill=$(( cur * w / tot ))
  local bar=""
  for ((i=0;i<fill;i++));  do bar+="█"; done
  for ((i=fill;i<w;i++));  do bar+="░"; done
  printf "\r  ${G}[%s]${N} ${W}%3d%%${N}  ${DIM}%s${N}" "$bar" "$pct" "$lbl"
}

# ══════════════════════════════════════════════════════════════════
# DISTRO DETECTION
# ══════════════════════════════════════════════════════════════════
DISTRO=""
PKG_MANAGER=""
PKG_INSTALL=""
PKG_UPDATE=""
DISTRO_FAMILY=""

detect_distro() {
  header_box "System Detection"

  local os_id="" os_like="" os_name=""
  if [[ -f /etc/os-release ]]; then
    os_id=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
    os_like=$(grep ^ID_LIKE= /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]' || true)
    os_name=$(grep ^PRETTY_NAME= /etc/os-release | cut -d= -f2 | tr -d '"')
  fi

  info "OS detected: ${W}${os_name}${N}"

  case "$os_id" in
    kali|parrot|parrotsec|debian|ubuntu|linuxmint|mint|pop)
      DISTRO_FAMILY="debian"
      PKG_MANAGER="apt"; PKG_INSTALL="apt install -y"; PKG_UPDATE="apt update -qq"
      ;;
    blackarch|arch|manjaro|endeavouros)
      DISTRO_FAMILY="arch"
      PKG_MANAGER="pacman"; PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy"
      ;;
    fedora|centos|rhel|rocky|almalinux)
      DISTRO_FAMILY="rhel"
      PKG_MANAGER="dnf"; PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update -q || true"
      ;;
    opensuse*|sles)
      DISTRO_FAMILY="suse"
      PKG_MANAGER="zypper"; PKG_INSTALL="zypper install -y"; PKG_UPDATE="zypper refresh"
      ;;
    *)
      # Fallback via ID_LIKE
      if echo "$os_like" | grep -qi "debian\|ubuntu"; then
        DISTRO_FAMILY="debian"; PKG_MANAGER="apt"
        PKG_INSTALL="apt install -y"; PKG_UPDATE="apt update -qq"
      elif echo "$os_like" | grep -qi "arch"; then
        DISTRO_FAMILY="arch"; PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"; PKG_UPDATE="pacman -Sy"
      elif echo "$os_like" | grep -qi "rhel\|fedora"; then
        DISTRO_FAMILY="rhel"; PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"; PKG_UPDATE="dnf check-update -q || true"
      else
        err "Unsupported distro: $os_id"
        err "Supported: Kali, Parrot, BlackArch, Ubuntu, Debian, Mint, Fedora, CentOS/RHEL, Arch, Manjaro, openSUSE"
        exit 1
      fi
      ;;
  esac

  DISTRO="$os_id"
  log "Distro  : ${C}${os_name}${N}"
  log "Family  : ${C}${DISTRO_FAMILY}${N}"
  log "Manager : ${C}${PKG_MANAGER}${N}"
}

# ══════════════════════════════════════════════════════════════════
# PACKAGE NAMES PER FAMILY
# ══════════════════════════════════════════════════════════════════
get_pkg() {
  local tool=$1
  case "$DISTRO_FAMILY" in
    debian) case "$tool" in
      nmap) echo "nmap" ;; whois) echo "whois" ;; dig) echo "dnsutils" ;;
      curl) echo "curl" ;; wget) echo "wget"   ;; whatweb) echo "whatweb" ;;
      openssl) echo "openssl" ;; tcpdump) echo "tcpdump" ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__" ;; *) echo "$tool" ;;
    esac ;;
    rhel) case "$tool" in
      nmap) echo "nmap" ;; whois) echo "whois" ;; dig) echo "bind-utils" ;;
      curl) echo "curl" ;; wget) echo "wget"   ;; whatweb) echo "__gem__" ;;
      openssl) echo "openssl" ;; tcpdump) echo "tcpdump" ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__" ;; *) echo "$tool" ;;
    esac ;;
    arch) case "$tool" in
      nmap) echo "nmap" ;; whois) echo "whois" ;; dig) echo "bind" ;;
      curl) echo "curl" ;; wget) echo "wget"   ;; whatweb) echo "whatweb" ;;
      openssl) echo "openssl" ;; tcpdump) echo "tcpdump" ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__" ;; *) echo "$tool" ;;
    esac ;;
    suse) case "$tool" in
      nmap) echo "nmap" ;; whois) echo "whois" ;; dig) echo "bind-utils" ;;
      curl) echo "curl" ;; wget) echo "wget"   ;; openssl) echo "openssl" ;;
      subfinder|httpx|nuclei|ffuf) echo "__go__" ;; *) echo "$tool" ;;
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
  [subfinder]="amass" [httpx]="curl" [nuclei]="nikto"
  [ffuf]="gobuster"   [whatweb]="curl"
)

# ══════════════════════════════════════════════════════════════════
# AUTOFIX ENGINE
# ══════════════════════════════════════════════════════════════════
install_go_tool() {
  local tool=$1
  local gopkg="${GO_TOOLS[$tool]:-}"
  [[ -z "$gopkg" ]] && return 1
  command -v go &>/dev/null || sudo $PKG_INSTALL golang &>/dev/null
  go install "$gopkg" &>/dev/null && export PATH="$PATH:$(go env GOPATH)/bin"
}

autofix() {
  local tool=$1
  fix "AUTOFIX: ${W}$tool${N}"

  # Step 1 — reinstall
  local pkg; pkg=$(get_pkg "$tool")
  if [[ "$pkg" == "__go__" ]]; then
    install_go_tool "$tool" && log "$tool installed via Go" && return 0
  elif [[ "$pkg" == "__gem__" ]]; then
    sudo gem install "$tool" &>/dev/null && log "$tool installed via gem" && return 0
  else
    fix "Reinstalling: $pkg"
    sudo $PKG_INSTALL "$pkg" &>/dev/null && log "$tool reinstalled" && return 0
  fi

  # Step 2 — fix permissions
  local tp; tp=$(which "$tool" 2>/dev/null || true)
  if [[ -n "$tp" ]]; then
    sudo chmod +x "$tp" && log "Permissions fixed: $tp" && return 0
  fi

  # Step 3 — suggest alternative
  local alt="${TOOL_ALT[$tool]:-}"
  if [[ -n "$alt" ]] && command -v "$alt" &>/dev/null; then
    warn "$tool unavailable → using alternative: ${W}$alt${N}"
    echo "$alt" > "$CACHE_DIR/alt_${tool}"
    return 0
  fi

  # Step 4 — retry with fix-missing (debian)
  if [[ "$DISTRO_FAMILY" == "debian" ]]; then
    fix "Retry with --fix-missing..."
    sudo apt-get install -y --fix-missing "$pkg" &>/dev/null && return 0
  fi

  err "AUTOFIX failed for $tool — module will be skipped"
  return 1
}

check_tool() {
  local tool=$1 required=${2:-false}
  if command -v "$tool" &>/dev/null; then
    log "Found   : ${C}$tool${N}  $(command -v $tool)"
    return 0
  fi
  warn "Missing : ${Y}$tool${N}"
  if [[ "$required" == "true" ]]; then
    act "Auto-installing: $tool"
    autofix "$tool" || true
  else
    echo -ne "  ${INF} Install optional ${W}$tool${N}? [y/N] "
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]] && autofix "$tool" || warn "Skipping $tool"
  fi
}

run_deps() {
  header_box "Dependency Check & Auto-Install"
  act "Updating package cache..."
  sudo $PKG_UPDATE &>/dev/null & spinner $! "Updating ${PKG_MANAGER}..."
  log "Cache updated"
  echo ""
  info "${W}Required:${N}"
  for t in nmap whois dig curl wget openssl; do check_tool "$t" true; done
  echo ""
  info "${W}Optional:${N}"
  for t in subfinder httpx whatweb nuclei ffuf; do check_tool "$t" false; done
  echo ""
  log "Dependency check complete"
}

# ══════════════════════════════════════════════════════════════════
# PLUGIN SYSTEM
# ══════════════════════════════════════════════════════════════════
init_dirs() {
  mkdir -p "$RECON_KIT_DIR" "$PLUGINS_DIR" "$CACHE_DIR"
  [[ ! -f "$CONFIG_FILE" ]] && cat > "$CONFIG_FILE" << 'CFG'
# recon-kit config
THREADS=10
TIMEOUT=30
AUTO_INSTALL=true
AUTO_FIX=true
USER_AGENT="recon-kit/2.0 (github.com/wavegxz-design/recon-kit)"
CFG
}

load_plugins() {
  local count=0
  compgen -G "$PLUGINS_DIR/*.sh" &>/dev/null || return 0
  for p in "$PLUGINS_DIR"/*.sh; do
    # shellcheck source=/dev/null
    source "$p" 2>/dev/null && { count=$((count+1)); info "Plugin: ${C}$(basename $p)${N}"; } \
      || warn "Plugin failed: $(basename $p)"
  done
  [[ $count -gt 0 ]] && log "$count plugin(s) loaded"
}

list_plugins() {
  header_box "Installed Plugins"
  compgen -G "$PLUGINS_DIR/*.sh" &>/dev/null || {
    info "No plugins installed."
    info "Drop .sh files into: ${C}$PLUGINS_DIR${N}"
    info "Community plugins: ${Y}github.com/wavegxz-design/recon-kit/wiki/plugins${N}"
    return
  }
  for p in "$PLUGINS_DIR"/*.sh; do
    local name; name=$(grep "^# PLUGIN:" "$p" 2>/dev/null | cut -d: -f2 | xargs || basename "$p")
    local desc; desc=$(grep "^# DESC:"   "$p" 2>/dev/null | cut -d: -f2 | xargs || echo "No description")
    echo -e "  ${G}→${N} ${W}$name${N} — ${DIM}$desc${N}"
  done
}

# ══════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════
TARGET="" OUTPUT_DIR="" MODULES=()
LOG_FILE="/tmp/recon-kit.log"
START_TIME=$(date +%s)

setup_output() {
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local safe; safe=$(echo "$TARGET" | tr '/:.' '_')
  OUTPUT_DIR="${RECON_KIT_DIR}/output/${safe}_${ts}"
  mkdir -p "$OUTPUT_DIR"/{nmap,dns,whois,subdomains,web,headers,cert,plugins}
  LOG_FILE="$OUTPUT_DIR/recon.log"
  { echo "# recon-kit v${VERSION}"
    echo "# Target : $TARGET"
    echo "# Date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# Distro : $DISTRO"
    echo "# Author : krypthane | wavegxz-design"; } > "$LOG_FILE"
  info "Output → ${W}$OUTPUT_DIR${N}"
}

# ══════════════════════════════════════════════════════════════════
# MODULES
# ══════════════════════════════════════════════════════════════════
module_whois() {
  section "WHOIS — $TARGET"
  local out="$OUTPUT_DIR/whois/whois.txt"
  whois "$TARGET" > "$out" 2>/dev/null || autofix whois
  log "Registrar : ${C}$(grep -i 'registrar:' "$out" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo N/A)${N}"
  log "Created   : ${C}$(grep -iE 'creation date|created:' "$out" 2>/dev/null | head -1 | awk '{print $NF}' || echo N/A)${N}"
  log "Expires   : ${C}$(grep -iE 'expir' "$out" 2>/dev/null | head -1 | awk '{print $NF}' || echo N/A)${N}"
  log "NS        : ${C}$(grep -iE 'name server|nserver' "$out" 2>/dev/null | head -3 | awk '{print $NF}' | tr '\n' ' ' || echo N/A)${N}"
  info "Full → $out"
}

module_dns() {
  section "DNS Enumeration — $TARGET"
  local out="$OUTPUT_DIR/dns/records.txt"
  local types=("A" "AAAA" "MX" "NS" "TXT" "SOA" "CNAME" "SRV" "CAA")
  for rtype in "${types[@]}"; do
    local res; res=$(dig +short "$rtype" "$TARGET" 2>/dev/null || true)
    if [[ -n "$res" ]]; then
      printf "%-8s %s\n" "[$rtype]" "$res" | tee -a "$out"
      log "$(printf '%-6s' $rtype): ${C}$res${N}"
    fi
  done
  # DMARC
  local dmarc; dmarc=$(dig +short TXT "_dmarc.$TARGET" 2>/dev/null || true)
  [[ -n "$dmarc" ]] && log "DMARC : ${C}$dmarc${N}"
  # Zone transfer
  info "Zone transfer attempt..."
  local ns; ns=$(dig +short NS "$TARGET" 2>/dev/null | head -1 || true)
  if [[ -n "$ns" ]]; then
    dig AXFR "$TARGET" "@$ns" > "$OUTPUT_DIR/dns/axfr.txt" 2>/dev/null
    local lines; lines=$(wc -l < "$OUTPUT_DIR/dns/axfr.txt" 2>/dev/null || echo 0)
    [[ $lines -gt 5 ]] && warn "Zone transfer SUCCEEDED → $OUTPUT_DIR/dns/axfr.txt" \
                       || info "Zone transfer blocked (normal)"
  fi
}

module_subdomains() {
  section "Subdomain Enumeration — $TARGET"
  local out="$OUTPUT_DIR/subdomains"
  local i=0

  # subfinder
  if command -v subfinder &>/dev/null; then
    act "Running subfinder..."
    subfinder -d "$TARGET" -silent -o "$out/subfinder.txt" 2>/dev/null &
    spinner $! "subfinder scanning $TARGET..."
    log "subfinder: ${G}$(wc -l < "$out/subfinder.txt" 2>/dev/null || echo 0)${N} found"
  fi

  # Common brute force
  act "Common subdomain brute force..."
  local common=("www" "mail" "ftp" "admin" "api" "dev" "staging" "vpn" "remote"
    "test" "portal" "dashboard" "cdn" "blog" "shop" "app" "mobile" "beta"
    "backup" "git" "jenkins" "grafana" "kibana" "jira" "wiki" "smtp"
    "ns1" "ns2" "mx" "relay" "webmail" "cpanel" "autodiscover")
  local total=${#common[@]} found=0
  for sub in "${common[@]}"; do
    i=$((i+1))
    progress_bar $i $total "Checking ${sub}.${TARGET}"
    local res; res=$(dig +short A "${sub}.${TARGET}" 2>/dev/null || true)
    if [[ -n "$res" ]]; then
      echo "${sub}.${TARGET} → $res" >> "$out/bruteforce.txt"
      found=$((found+1))
    fi
  done
  echo ""
  log "Brute force: ${G}$found${N} found"

  # Merge
  cat "$out"/*.txt 2>/dev/null | grep -oP "[\w\-\.]+\.${TARGET}" | sort -u > "$out/all.txt" || true
  log "Total unique: ${G}$(wc -l < "$out/all.txt" 2>/dev/null || echo 0)${N} → $out/all.txt"
}

module_portscan() {
  section "Port Scan — $TARGET"
  local out="$OUTPUT_DIR/nmap"

  act "Quick scan — top 1000 ports..."
  nmap -sV --open -T4 -oN "$out/quick.txt" -oX "$out/quick.xml" "$TARGET" 2>/dev/null \
    | grep -E "^[0-9]+|Nmap scan|open" | tee -a "$LOG_FILE" || autofix nmap

  act "Full TCP scan (background — all 65535 ports)..."
  nmap -sV -p- --open -T3 -oN "$out/full.txt" "$TARGET" &>/dev/null &
  log "Full scan PID $! → $out/full.txt"

  if [[ $EUID -eq 0 ]]; then
    act "UDP top 100..."
    nmap -sU --top-ports 100 -T4 -oN "$out/udp.txt" "$TARGET" &>/dev/null &
    log "UDP scan PID $! → $out/udp.txt"
  else
    warn "UDP scan requires root — run with sudo to enable"
  fi

  echo ""
  info "${W}Open ports:${N}"
  grep "^[0-9]" "$out/quick.txt" 2>/dev/null \
    | while read -r line; do echo -e "  ${G}→${N} $line"; done | tee -a "$LOG_FILE"
}

module_web() {
  section "Web Reconnaissance — $TARGET"
  local out="$OUTPUT_DIR/web"
  local hout="$OUTPUT_DIR/headers"
  local url="https://${TARGET}"

  act "Grabbing headers..."
  curl -sIL --max-time 15 "$url"            > "$hout/https.txt" 2>/dev/null || true
  curl -sIL --max-time 15 "http://$TARGET"  > "$hout/http.txt"  2>/dev/null || true

  info "${W}Security headers audit:${N}"
  local headers=("Strict-Transport-Security" "Content-Security-Policy"
    "X-Frame-Options" "X-Content-Type-Options" "Referrer-Policy"
    "Permissions-Policy" "X-XSS-Protection" "Cross-Origin-Opener-Policy")
  local present=0 missing=0
  for h in "${headers[@]}"; do
    if grep -qi "$h" "$hout/https.txt" 2>/dev/null; then
      echo -e "  ${G}[PRESENT]${N} $h" | tee -a "$LOG_FILE"; ((present++))
    else
      echo -e "  ${R}[MISSING]${N} $h" | tee -a "$LOG_FILE"; ((missing++))
    fi
  done
  log "Headers: ${G}$present present${N} / ${R}$missing missing${N}"

  command -v whatweb &>/dev/null && {
    act "WhatWeb detection..."
    whatweb -a 3 "$url" > "$out/whatweb.txt" 2>/dev/null
    log "Tech → $out/whatweb.txt"
  }

  act "Common files check..."
  for p in "robots.txt" "sitemap.xml" ".well-known/security.txt" "crossdomain.xml" "humans.txt"; do
    local code; code=$(curl -so /dev/null -w "%{http_code}" --max-time 8 "${url}/${p}" 2>/dev/null || echo 000)
    [[ "$code" == "200" ]] && {
      curl -s --max-time 8 "${url}/${p}" > "$out/${p//\//_}" 2>/dev/null
      log "Found: /${p} ${G}[200]${N}"
    }
  done

  command -v httpx &>/dev/null && [[ -f "$OUTPUT_DIR/subdomains/all.txt" ]] && {
    act "Probing live subdomains..."
    httpx -l "$OUTPUT_DIR/subdomains/all.txt" -silent -status-code -title \
      > "$out/live_hosts.txt" 2>/dev/null
    log "Live hosts: ${G}$(wc -l < "$out/live_hosts.txt" 2>/dev/null || echo 0)${N}"
  }
}

module_cert() {
  section "SSL/TLS Certificate — $TARGET"
  local out="$OUTPUT_DIR/cert/cert.txt"

  echo | timeout 10 openssl s_client -connect "${TARGET}:443" \
    -servername "$TARGET" 2>/dev/null | openssl x509 -noout -text > "$out" 2>/dev/null || {
    autofix openssl; warn "Could not retrieve certificate"; return
  }

  log "Subject : ${C}$(grep 'Subject:' "$out" 2>/dev/null | head -1 | xargs)${N}"
  log "Issuer  : ${C}$(grep 'Issuer:'  "$out" 2>/dev/null | head -1 | xargs)${N}"
  log "Expires : ${C}$(grep 'Not After' "$out" 2>/dev/null | head -1 | xargs)${N}"
  log "SANs    : ${C}$(grep -A2 'Subject Alternative Name' "$out" 2>/dev/null | tail -1 | xargs)${N}"

  local exp; exp=$(grep "Not After" "$out" 2>/dev/null | cut -d: -f2- | xargs)
  if [[ -n "$exp" ]]; then
    local exp_e; exp_e=$(date -d "$exp" +%s 2>/dev/null || true)
    local now_e; now_e=$(date +%s)
    local days=$(( (exp_e - now_e) / 86400 ))
    [[ $days -lt 30 ]] && warn "Expires in ${R}$days days!${N}" || log "Valid for ${G}$days more days${N}"
  fi
}

# ══════════════════════════════════════════════════════════════════
# FINAL REPORT
# ══════════════════════════════════════════════════════════════════
generate_report() {
  local end_t; end_t=$(date +%s)
  local elapsed=$(( end_t - START_TIME ))
  local open_ports; open_ports=$(grep -c "^[0-9]" "$OUTPUT_DIR/nmap/quick.txt" 2>/dev/null || echo 0)
  local subs;       subs=$(wc -l < "$OUTPUT_DIR/subdomains/all.txt" 2>/dev/null || echo 0)
  local miss_h;     miss_h=$(grep -c "\[MISSING\]" "$LOG_FILE" 2>/dev/null || echo 0)
  local report="$OUTPUT_DIR/REPORT.md"

  cat > "$report" << RPT
# recon-kit Report — ${TARGET}

| Field    | Value |
|----------|-------|
| Target   | ${TARGET} |
| Date     | $(date '+%Y-%m-%d %H:%M:%S') |
| Duration | ${elapsed}s |
| Distro   | ${DISTRO} |
| Operator | krypthane \| wavegxz-design |

## Summary

| Metric              | Result |
|---------------------|--------|
| Open ports (quick)  | ${open_ports} |
| Subdomains found    | ${subs} |
| Missing sec headers | ${miss_h} |
| Modules run         | ${#MODULES[@]} |

## Modules
$(for m in "${MODULES[@]}"; do echo "- $m"; done)

## Output Files
$(find "$OUTPUT_DIR" -type f | sort | sed "s|$OUTPUT_DIR/||" | sed 's/^/- /')

---
*recon-kit v${VERSION} — github.com/wavegxz-design/recon-kit*
*Authorized use only.*
RPT

  echo ""
  sep_full
  echo -e "  ${W}${BOLD}SCAN COMPLETE${N}"
  sep
  printf "  ${INF} %-20s ${G}%s${N}\n" "Target:"    "$TARGET"
  printf "  ${INF} %-20s ${C}%ss${N}\n" "Duration:"  "$elapsed"
  printf "  ${INF} %-20s ${G}%s${N}\n" "Open ports:" "$open_ports"
  printf "  ${INF} %-20s ${G}%s${N}\n" "Subdomains:" "$subs"
  printf "  ${INF} %-20s ${R}%s${N}\n" "Missing headers:" "$miss_h"
  printf "  ${INF} %-20s ${Y}%s${N}\n" "Output dir:"  "$OUTPUT_DIR"
  printf "  ${INF} %-20s ${Y}%s${N}\n" "Report:"      "$report"
  sep_full
  echo ""
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
  echo -ne "  ${G}[>]${N} Choice: "
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
      echo -ne "  ${G}[>]${N} Modules ${DIM}(whois,dns,subdomains,portscan,web,cert)${N}: "
      read -r custom; IFS=',' read -ra MODULES <<< "$custom" ;;
    p) list_plugins; exit 0 ;;
    q) echo -e "\n  ${DIM}Bye.${N}\n"; exit 0 ;;
    *) err "Invalid option"; exit 1 ;;
  esac
}

usage() {
  echo -e "${W}Usage:${N} $0 -t <target> [options]"
  echo -e "  -t  Target domain or IP"
  echo -e "  -m  Modules: all | whois,dns,subdomains,portscan,web,cert"
  echo -e "  -p  List plugins"
  echo -e "  -h  Help"
  echo ""
  echo -e "${W}Examples:${N}"
  echo -e "  $0 -t example.com -m all"
  echo -e "  sudo $0 -t example.com -m all   ${DIM}# enables UDP${N}"
  echo -e "${R}  Authorized targets only.${N}"
}

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════
main() {
  init_dirs
  banner

  while getopts "t:m:ph" opt; do
    case $opt in
      t) TARGET="$OPTARG" ;;
      m) IFS=',' read -ra MODULES <<< "$OPTARG" ;;
      p) list_plugins; exit 0 ;;
      h) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
  done

  [[ -z "$TARGET" ]] && {
    echo -ne "  ${G}[>]${N} Target domain or IP: "
    read -r TARGET
  }
  [[ -z "$TARGET" ]] && { err "No target"; usage; exit 1; }

  detect_distro
  setup_output
  run_deps
  load_plugins

  [[ ${#MODULES[@]} -eq 0 ]] && show_menu
  [[ "${MODULES[*]}" == *"all"* ]] && MODULES=("whois" "dns" "subdomains" "portscan" "web" "cert")

  sep_full
  info "Target  : ${W}$TARGET${N}"
  info "Modules : ${C}${MODULES[*]}${N}"
  info "Output  : ${Y}$OUTPUT_DIR${N}"
  sep_full

  local total=${#MODULES[@]} cur=0
  for module in "${MODULES[@]}"; do
    cur=$((cur+1))
    progress_bar $cur $total "Running: $module"
    echo ""
    case $module in
      whois)      module_whois ;;
      dns)        module_dns ;;
      subdomains) module_subdomains ;;
      portscan)   module_portscan ;;
      web)        module_web ;;
      cert)       module_cert ;;
      *)
        declare -f "plugin_${module}" &>/dev/null \
          && "plugin_${module}" \
          || warn "Unknown module: $module"
        ;;
    esac
  done

  generate_report
}

main "$@"
