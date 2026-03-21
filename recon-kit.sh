#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              RECON-KIT — Reconnaissance Toolkit             ║
# ║         Author  : krypthane | wavegxz-design                ║
# ║         GitHub  : github.com/wavegxz-design/recon-kit       ║
# ║         License : MIT                                        ║
# ║                                                              ║
# ║   USE ONLY ON SYSTEMS YOU OWN OR HAVE WRITTEN PERMISSION.   ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── COLORS ──────────────────────────────────────────────────────
R='\033[0;31m'  G='\033[0;32m'  Y='\033[1;33m'
B='\033[0;34m'  C='\033[0;36m'  W='\033[1;37m'  N='\033[0m'

# ── BANNER ──────────────────────────────────────────────────────
banner() {
cat << 'EOF'
  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗      ██╗  ██╗██╗████████╗
  ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║      ██║ ██╔╝██║╚══██╔══╝
  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║█████╗█████╔╝ ██║   ██║
  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║╚════╝██╔═██╗ ██║   ██║
  ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║      ██║  ██╗██║   ██║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝      ╚═╝  ╚═╝╚═╝   ╚═╝
EOF
  echo -e "  ${G}Reconnaissance Toolkit${N} | ${C}krypthane${N} | ${Y}github.com/wavegxz-design${N}"
  echo -e "  ${R}[!] Use only on authorized targets. Unauthorized use is illegal.${N}\n"
}

# ── CONFIG ───────────────────────────────────────────────────────
TARGET=""
OUTPUT_DIR=""
MODULES=()
LOG_FILE=""
START_TIME=$(date +%s)

# ── LOGGING ──────────────────────────────────────────────────────
log()  { echo -e "${G}[+]${N} $*" | tee -a "$LOG_FILE"; }
info() { echo -e "${C}[*]${N} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${Y}[!]${N} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${R}[✗]${N} $*" | tee -a "$LOG_FILE"; }
sep()  { echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}" | tee -a "$LOG_FILE"; }

# ── DEPENDENCY CHECK ─────────────────────────────────────────────
check_deps() {
  local deps=("nmap" "whois" "dig" "curl" "wget")
  local optional=("subfinder" "httpx" "nuclei" "ffuf" "whatweb")
  local missing=()

  info "Checking dependencies..."
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
      err "Missing (required): $dep"
    else
      log "Found: $dep"
    fi
  done

  for dep in "${optional[@]}"; do
    if command -v "$dep" &>/dev/null; then
      log "Found (optional): $dep"
    else
      warn "Not found (optional): $dep — some modules will be skipped"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Install missing deps: sudo apt install ${missing[*]}"
    exit 1
  fi
}

# ── SETUP OUTPUT DIR ─────────────────────────────────────────────
setup_output() {
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local safe_target; safe_target=$(echo "$TARGET" | tr '/:.' '_')
  OUTPUT_DIR="recon-output/${safe_target}_${ts}"
  mkdir -p "$OUTPUT_DIR"/{nmap,dns,whois,subdomains,web,headers,screenshots}
  LOG_FILE="$OUTPUT_DIR/recon.log"
  touch "$LOG_FILE"
  info "Output directory: $OUTPUT_DIR"
}

# ══════════════════════════════════════════════════════════════════
# MÓDULOS
# ══════════════════════════════════════════════════════════════════

# ── MODULE: WHOIS ────────────────────────────────────────────────
module_whois() {
  sep; log "MODULE: WHOIS — $TARGET"
  local out="$OUTPUT_DIR/whois/whois.txt"

  whois "$TARGET" > "$out" 2>/dev/null && log "WHOIS saved → $out" || warn "WHOIS failed"

  # Extract key fields
  local registrar; registrar=$(grep -i "registrar:" "$out" 2>/dev/null | head -1 || echo "N/A")
  local creation; creation=$(grep -i "creation date\|created:" "$out" 2>/dev/null | head -1 || echo "N/A")
  local expiry; expiry=$(grep -i "expir" "$out" 2>/dev/null | head -1 || echo "N/A")

  info "Registrar : $registrar"
  info "Created   : $creation"
  info "Expires   : $expiry"
}

# ── MODULE: DNS ──────────────────────────────────────────────────
module_dns() {
  sep; log "MODULE: DNS Enumeration — $TARGET"
  local out="$OUTPUT_DIR/dns"

  local record_types=("A" "AAAA" "MX" "NS" "TXT" "SOA" "CNAME" "PTR" "SRV")

  for rtype in "${record_types[@]}"; do
    local result; result=$(dig +short "$rtype" "$TARGET" 2>/dev/null)
    if [[ -n "$result" ]]; then
      echo "[$rtype]" >> "$out/dns_records.txt"
      echo "$result"  >> "$out/dns_records.txt"
      echo ""         >> "$out/dns_records.txt"
      log "$rtype → $result"
    fi
  done

  # Zone transfer attempt (for auditing — usually blocked)
  info "Attempting zone transfer (AXFR)..."
  local ns; ns=$(dig +short NS "$TARGET" 2>/dev/null | head -1)
  if [[ -n "$ns" ]]; then
    dig AXFR "$TARGET" "@$ns" > "$out/zone_transfer.txt" 2>/dev/null
    local lines; lines=$(wc -l < "$out/zone_transfer.txt")
    [[ $lines -gt 5 ]] && warn "Zone transfer succeeded! Check $out/zone_transfer.txt" \
                       || info "Zone transfer blocked (expected)"
  fi
}

# ── MODULE: SUBDOMAIN ENUMERATION ───────────────────────────────
module_subdomains() {
  sep; log "MODULE: Subdomain Enumeration — $TARGET"
  local out="$OUTPUT_DIR/subdomains"

  # Method 1: subfinder (if available)
  if command -v subfinder &>/dev/null; then
    info "Running subfinder..."
    subfinder -d "$TARGET" -silent -o "$out/subfinder.txt" 2>/dev/null
    local count; count=$(wc -l < "$out/subfinder.txt" 2>/dev/null || echo 0)
    log "subfinder found $count subdomains"
  fi

  # Method 2: DNS brute force with wordlist
  local wordlist="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
  if [[ -f "$wordlist" ]]; then
    info "Running DNS brute force..."
    while IFS= read -r sub; do
      local result; result=$(dig +short A "${sub}.${TARGET}" 2>/dev/null)
      if [[ -n "$result" ]]; then
        echo "${sub}.${TARGET} → $result" | tee -a "$out/bruteforce.txt"
      fi
    done < "$wordlist"
  else
    warn "Wordlist not found: $wordlist — install seclists"
    # Fallback: common subdomains
    local common=("www" "mail" "ftp" "admin" "api" "dev" "staging" "vpn"
                  "remote" "test" "portal" "dashboard" "cdn" "blog" "shop")
    info "Trying common subdomains..."
    for sub in "${common[@]}"; do
      local result; result=$(dig +short A "${sub}.${TARGET}" 2>/dev/null)
      [[ -n "$result" ]] && echo "${sub}.${TARGET} → $result" | tee -a "$out/common.txt"
    done
  fi

  # Merge and deduplicate
  cat "$out"/*.txt 2>/dev/null | sort -u > "$out/all_subdomains.txt"
  local total; total=$(wc -l < "$out/all_subdomains.txt" 2>/dev/null || echo 0)
  log "Total unique subdomains found: $total → $out/all_subdomains.txt"
}

# ── MODULE: PORT SCAN ────────────────────────────────────────────
module_portscan() {
  sep; log "MODULE: Port Scan — $TARGET"
  local out="$OUTPUT_DIR/nmap"

  # Quick scan — top 1000 ports
  info "Quick scan (top 1000 ports)..."
  nmap -sV --open -T4 \
    -oN "$out/quick_scan.txt" \
    -oX "$out/quick_scan.xml" \
    "$TARGET" 2>/dev/null | tee -a "$LOG_FILE"

  # Full TCP scan (background, slower)
  info "Full TCP scan running in background → $out/full_scan.txt"
  nmap -sV -p- --open -T3 \
    -oN "$out/full_scan.txt" \
    "$TARGET" &>/dev/null &
  log "Full scan PID: $! (running in background)"

  # UDP top 100
  if [[ $EUID -eq 0 ]]; then
    info "UDP scan (top 100)..."
    nmap -sU --top-ports 100 -T4 \
      -oN "$out/udp_scan.txt" \
      "$TARGET" 2>/dev/null &
  else
    warn "UDP scan skipped — requires root (run with sudo)"
  fi
}

# ── MODULE: WEB RECON ────────────────────────────────────────────
module_web() {
  sep; log "MODULE: Web Reconnaissance — $TARGET"
  local out="$OUTPUT_DIR/web"
  local url="https://${TARGET}"

  # HTTP headers
  info "Grabbing HTTP headers..."
  curl -sI "$url" > "$OUTPUT_DIR/headers/https_headers.txt" 2>/dev/null
  curl -sI "http://${TARGET}" > "$OUTPUT_DIR/headers/http_headers.txt" 2>/dev/null

  # Security headers check
  info "Checking security headers..."
  local headers_file="$OUTPUT_DIR/headers/https_headers.txt"
  local sec_headers=("Strict-Transport-Security" "Content-Security-Policy"
                     "X-Frame-Options" "X-Content-Type-Options"
                     "Referrer-Policy" "Permissions-Policy")

  echo "=== Security Headers Audit ===" > "$OUTPUT_DIR/headers/security_audit.txt"
  for header in "${sec_headers[@]}"; do
    if grep -qi "$header" "$headers_file" 2>/dev/null; then
      echo "[PRESENT] $header" | tee -a "$OUTPUT_DIR/headers/security_audit.txt"
      log "Header present: $header"
    else
      echo "[MISSING] $header" | tee -a "$OUTPUT_DIR/headers/security_audit.txt"
      warn "Header missing: $header"
    fi
  done

  # Tech detection
  if command -v whatweb &>/dev/null; then
    info "Running WhatWeb..."
    whatweb -a 3 "$url" > "$out/whatweb.txt" 2>/dev/null
    log "WhatWeb output → $out/whatweb.txt"
  fi

  # robots.txt & sitemap
  for path in "robots.txt" "sitemap.xml" ".well-known/security.txt"; do
    local resp; resp=$(curl -so /dev/null -w "%{http_code}" "${url}/${path}" 2>/dev/null)
    if [[ "$resp" == "200" ]]; then
      curl -s "${url}/${path}" > "$out/${path//\//_}" 2>/dev/null
      log "Found: /${path} (200)"
    fi
  done

  # httpx alive check (if available)
  if command -v httpx &>/dev/null && [[ -f "$OUTPUT_DIR/subdomains/all_subdomains.txt" ]]; then
    info "Checking live subdomains with httpx..."
    grep -oP '[\w\-\.]+\.' "$OUTPUT_DIR/subdomains/all_subdomains.txt" 2>/dev/null \
      | httpx -silent -status-code -title \
      > "$out/live_subdomains.txt" 2>/dev/null
    log "Live subdomains → $out/live_subdomains.txt"
  fi
}

# ── MODULE: CERTIFICATE INFO ─────────────────────────────────────
module_cert() {
  sep; log "MODULE: SSL/TLS Certificate — $TARGET"
  local out="$OUTPUT_DIR/web/cert_info.txt"

  echo | openssl s_client -connect "${TARGET}:443" -servername "$TARGET" 2>/dev/null \
    | openssl x509 -noout -text > "$out" 2>/dev/null

  local subject; subject=$(grep "Subject:" "$out" 2>/dev/null | head -1)
  local issuer;  issuer=$(grep "Issuer:" "$out" 2>/dev/null | head -1)
  local expiry;  expiry=$(grep "Not After" "$out" 2>/dev/null | head -1)
  local sans;    sans=$(grep -A1 "Subject Alternative Name" "$out" 2>/dev/null | tail -1)

  info "Subject : $subject"
  info "Issuer  : $issuer"
  info "Expiry  : $expiry"
  info "SANs    : $sans"
  log "Full cert → $out"
}

# ══════════════════════════════════════════════════════════════════
# REPORT GENERATOR
# ══════════════════════════════════════════════════════════════════
generate_report() {
  sep
  local end_time=$(date +%s)
  local elapsed=$(( end_time - START_TIME ))
  local report="$OUTPUT_DIR/REPORT.md"

  cat > "$report" << REPORT
# Recon Report — ${TARGET}
**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Duration:** ${elapsed}s
**Operator:** krypthane | wavegxz-design
**Output:** ${OUTPUT_DIR}

---

## Modules Run
$(for m in "${MODULES[@]}"; do echo "- $m"; done)

## Files Generated
$(find "$OUTPUT_DIR" -type f | sort | sed "s|$OUTPUT_DIR/||")

---
*Generated by recon-kit — github.com/wavegxz-design/recon-kit*
*Use only on authorized targets.*
REPORT

  log "Report generated → $report"
  echo ""
  echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
  echo -e "${W}  Recon complete — ${TARGET}${N}"
  echo -e "${C}  Duration : ${elapsed}s${N}"
  echo -e "${C}  Output   : ${OUTPUT_DIR}${N}"
  echo -e "${C}  Report   : ${report}${N}"
  echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
}

# ══════════════════════════════════════════════════════════════════
# MENU & USAGE
# ══════════════════════════════════════════════════════════════════
usage() {
  echo -e "${W}Usage:${N}"
  echo -e "  $0 -t <target> [options]"
  echo ""
  echo -e "${W}Options:${N}"
  echo -e "  -t  Target domain or IP (required)"
  echo -e "  -m  Modules: all | whois,dns,subdomains,portscan,web,cert"
  echo -e "  -h  Show this help"
  echo ""
  echo -e "${W}Examples:${N}"
  echo -e "  $0 -t example.com -m all"
  echo -e "  $0 -t example.com -m whois,dns,portscan"
  echo -e "  $0 -t 192.168.1.1 -m portscan,web"
  echo ""
  echo -e "${R}  Only use on targets you own or have written authorization to test.${N}"
}

interactive_menu() {
  echo -e "\n${W}Select modules to run:${N}"
  echo -e "  ${C}1${N}) All modules"
  echo -e "  ${C}2${N}) WHOIS only"
  echo -e "  ${C}3${N}) DNS Enumeration"
  echo -e "  ${C}4${N}) Subdomain Enumeration"
  echo -e "  ${C}5${N}) Port Scan"
  echo -e "  ${C}6${N}) Web Reconnaissance"
  echo -e "  ${C}7${N}) SSL/TLS Certificate"
  echo -e "  ${C}8${N}) Custom selection"
  echo ""
  read -rp "$(echo -e "${G}[>]${N} Choose: ")" choice

  case $choice in
    1) MODULES=("whois" "dns" "subdomains" "portscan" "web" "cert") ;;
    2) MODULES=("whois") ;;
    3) MODULES=("dns") ;;
    4) MODULES=("subdomains") ;;
    5) MODULES=("portscan") ;;
    6) MODULES=("web") ;;
    7) MODULES=("cert") ;;
    8)
      echo -e "Enter modules separated by comma ${C}(whois,dns,subdomains,portscan,web,cert)${N}:"
      read -rp "$(echo -e "${G}[>]${N} ")" custom
      IFS=',' read -ra MODULES <<< "$custom"
      ;;
    *) err "Invalid option"; exit 1 ;;
  esac
}

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════
main() {
  banner

  # Parse args
  while getopts "t:m:h" opt; do
    case $opt in
      t) TARGET="$OPTARG" ;;
      m) IFS=',' read -ra MODULES <<< "$OPTARG" ;;
      h) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
  done

  # Target required
  if [[ -z "$TARGET" ]]; then
    read -rp "$(echo -e "${G}[>]${N} Enter target domain or IP: ")" TARGET
  fi

  [[ -z "$TARGET" ]] && { err "Target required"; usage; exit 1; }

  # Module selection
  [[ ${#MODULES[@]} -eq 0 ]] && interactive_menu

  # Expand "all"
  if [[ "${MODULES[*]}" == *"all"* ]]; then
    MODULES=("whois" "dns" "subdomains" "portscan" "web" "cert")
  fi

  # Init
  check_deps
  setup_output

  sep
  info "Target  : $TARGET"
  info "Modules : ${MODULES[*]}"
  info "Output  : $OUTPUT_DIR"
  sep

  # Run modules
  for module in "${MODULES[@]}"; do
    case $module in
      whois)      module_whois ;;
      dns)        module_dns ;;
      subdomains) module_subdomains ;;
      portscan)   module_portscan ;;
      web)        module_web ;;
      cert)       module_cert ;;
      *) warn "Unknown module: $module — skipping" ;;
    esac
  done

  generate_report
}

main "$@"
