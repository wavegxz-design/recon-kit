<div align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:00ff41,100:003b00&height=200&section=header&text=recon-kit&fontSize=80&fontColor=ffffff&fontAlignY=38&desc=Modular%20Reconnaissance%20Toolkit&descAlignY=60&descColor=00ff41&animation=fadeIn" width="100%"/>
</div>

<div align="center">

<br>

[![Release](https://img.shields.io/github/v/release/wavegxz-design/recon-kit?include_prereleases&style=for-the-badge&logo=github&color=00ff41&labelColor=0d1117)](https://github.com/wavegxz-design/recon-kit/releases)
[![License](https://img.shields.io/badge/License-MIT-00ff41?style=for-the-badge&labelColor=0d1117)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash_5.0+-00ff41?style=for-the-badge&logo=gnubash&logoColor=white&labelColor=0d1117)](https://github.com/wavegxz-design/recon-kit)
[![Platform](https://img.shields.io/badge/Platform-Linux-00ff41?style=for-the-badge&logo=linux&logoColor=white&labelColor=0d1117)](https://github.com/wavegxz-design/recon-kit)
[![Distros](https://img.shields.io/badge/Distros-8_Supported-00ff41?style=for-the-badge&logo=debian&logoColor=white&labelColor=0d1117)](https://github.com/wavegxz-design/recon-kit)
[![Stars](https://img.shields.io/github/stars/wavegxz-design/recon-kit?style=for-the-badge&logo=starship&color=00ff41&labelColor=0d1117)](https://github.com/wavegxz-design/recon-kit/stargazers)

<br>

> **Modular, distro-aware, self-healing reconnaissance toolkit.**
> Built for pentesters who don't waste time fixing broken environments.

<br>

[**Documentation**](#-documentation) · [**Quick Start**](#-quick-start) · [**Modules**](#-modules) · [**Auto-Update**](#-auto-update) · [**Plugins**](#-plugin-system) · [**Contributing**](#-contributing) · [**Roadmap**](#-roadmap)

<br>

</div>

---

## 📌 Overview

**recon-kit** is a senior-level modular reconnaissance toolkit written entirely in Bash.

It detects your Linux distribution automatically, resolves and installs every missing dependency through your native package manager, runs 6 independent recon modules with live visual feedback, auto-recovers from tool failures through its built-in AUTOFIX engine, and produces a structured Markdown report — all without any manual configuration.

```
One command. Any distro. Full recon.
```

<br>

## ⚡ Quick Start

```bash
git clone https://github.com/wavegxz-design/recon-kit
cd recon-kit && chmod +x recon-kit.sh

# Interactive mode
./recon-kit.sh -t target.com

# Full scan, all modules
./recon-kit.sh -t target.com -m all

# Full scan with UDP (root required)
sudo ./recon-kit.sh -t target.com -m all
```

> ⚠️ **Authorized targets only.** Unauthorized reconnaissance is illegal.

<br>

---

## 📦 Modules

<table>
<thead>
<tr>
<th align="center">Module</th>
<th align="center">Flag</th>
<th align="center">Tools</th>
<th>What it does</th>
</tr>
</thead>
<tbody>
<tr>
<td align="center">🔍 WHOIS</td>
<td align="center"><code>whois</code></td>
<td align="center">whois</td>
<td>Registrar, creation/expiry dates, nameservers — auto-extracts root domain from subdomains</td>
</tr>
<tr>
<td align="center">🌐 DNS</td>
<td align="center"><code>dns</code></td>
<td align="center">dig</td>
<td>A, AAAA, MX, NS, TXT, SOA, SRV, CAA, DMARC — plus zone transfer attempt</td>
</tr>
<tr>
<td align="center">🕵️ Subdomains</td>
<td align="center"><code>subdomains</code></td>
<td align="center">subfinder, dig</td>
<td>Passive discovery via subfinder + 35-entry active brute force</td>
</tr>
<tr>
<td align="center">🔌 Port Scan</td>
<td align="center"><code>portscan</code></td>
<td align="center">nmap</td>
<td>Quick top-1000 · Full TCP 65535 (background) · UDP top-100 (root)</td>
</tr>
<tr>
<td align="center">🕸️ Web Recon</td>
<td align="center"><code>web</code></td>
<td align="center">curl, httpx, whatweb</td>
<td>Security headers audit · tech fingerprint · robots.txt · live hosts</td>
</tr>
<tr>
<td align="center">🔐 SSL/TLS</td>
<td align="center"><code>cert</code></td>
<td align="center">openssl</td>
<td>Subject, issuer, SANs, expiry countdown, weak cipher detection</td>
</tr>
</tbody>
</table>

**Run specific modules:**
```bash
./recon-kit.sh -t target.com -m whois,dns,portscan
./recon-kit.sh -t target.com -m subdomains,web,cert
```

<br>

---

## 🐧 Supported Distributions

<table>
<thead>
<tr>
<th align="center">Family</th>
<th>Distributions</th>
<th align="center">Package Manager</th>
<th align="center">Status</th>
</tr>
</thead>
<tbody>
<tr>
<td align="center"><strong>Debian</strong></td>
<td>Kali Linux · Parrot OS · Ubuntu · Debian · Linux Mint · Pop!_OS</td>
<td align="center"><code>apt</code></td>
<td align="center">✅ Stable</td>
</tr>
<tr>
<td align="center"><strong>Arch</strong></td>
<td>Arch Linux · Manjaro · EndeavourOS · BlackArch</td>
<td align="center"><code>pacman</code></td>
<td align="center">✅ Stable</td>
</tr>
<tr>
<td align="center"><strong>RHEL</strong></td>
<td>Fedora · CentOS · RHEL · Rocky Linux · AlmaLinux</td>
<td align="center"><code>dnf</code></td>
<td align="center">✅ Stable</td>
</tr>
<tr>
<td align="center"><strong>SUSE</strong></td>
<td>openSUSE Leap · Tumbleweed</td>
<td align="center"><code>zypper</code></td>
<td align="center">🔄 Beta</td>
</tr>
</tbody>
</table>

<br>

---

## ⚙️ AUTOFIX Engine

recon-kit never crashes silently. When a tool fails or is missing, the AUTOFIX engine runs a 4-step recovery chain before skipping any module:

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTOFIX RECOVERY CHAIN                   │
├──────┬──────────────────────────────────────────────────────┤
│  01  │  Reinstall via package manager / go install / gem    │
│  02  │  Repair binary permissions  (chmod +x)               │
│  03  │  Switch to available alternative tool                 │
│  04  │  Retry with --fix-missing or distro equivalent        │
└──────┴──────────────────────────────────────────────────────┘
```

Every failure is timestamped and logged to `recon.log`. Nothing is swallowed.

<br>

---

## 🔄 Auto-Update

recon-kit includes a built-in update system with backup and rollback support — no manual file replacement needed.

### Commands

```bash
# Check and apply latest update interactively
./recon-kit.sh --update

# Check for updates without installing
./recon-kit.sh --check

# Roll back to a previous version from backup
./recon-kit.sh --rollback

# Run the update module standalone
bash update.sh
bash update.sh --check
bash update.sh --rollback
```

### How it works

```
┌─────────────────────────────────────────────────────────────┐
│                    UPDATE SAFETY CHAIN                      │
├──────┬──────────────────────────────────────────────────────┤
│  01  │  Fetch latest release tag from GitHub API            │
│  02  │  Show changelog between current → latest             │
│  03  │  Backup current version with timestamp               │
│  04  │  Download new version to /tmp                        │
│  05  │  Validate bash syntax  (bash -n)                     │
│  06  │  Verify VERSION= matches release tag                 │
│  07  │  Replace script · if fails → auto-restore backup     │
└──────┴──────────────────────────────────────────────────────┘
```

### Silent background check

On every launch, recon-kit silently checks for updates **once per 24 hours** in a background process — no delay on startup. If a new version is available, a notice appears alongside the banner:

```
 ┌────────────────────────────────────────────────────────┐
 │  Update available: 2.1.0 → 2.2.0                      │
 │  Run: ./recon-kit.sh --update                          │
 │  krypthane.workernova.workers.dev                      │
 └────────────────────────────────────────────────────────┘
```

### Rollback

Every update creates a timestamped backup. The `--rollback` flag shows an interactive menu to restore any previous version:

```bash
./recon-kit.sh --rollback

  Available backups:
  ──────────────────────────────────────────────────────────
  1) recon-kit_backup_20260321_172135.sh  (v2.0.0)
  2) recon-kit_backup_20260318_091020.sh  (v1.0.0)
  ──────────────────────────────────────────────────────────
  [>] Select backup (1-2):
```

<br>

---

## 🔌 Plugin System

Extend recon-kit without touching the core. Drop any `.sh` file into `~/.recon-kit/plugins/` — it loads automatically on startup.

**Plugin template:**

```bash
# PLUGIN: my-module
# DESC:   One-line description of what this does
# AUTHOR: yourhandle

plugin_mymodule() {
  section "MY MODULE — $TARGET"
  # log() info() warn() err() act() for consistent output
  local out="$OUTPUT_DIR/plugins/mymodule.txt"
  log "Done → $out"
}
```

**Invoke it:**
```bash
./recon-kit.sh -t target.com -m mymodule
./recon-kit.sh -p   # list all installed plugins
```

> 📚 Community plugins → [wiki/plugins](https://github.com/wavegxz-design/recon-kit/wiki/plugins)

<br>

---

## 📁 Output Structure

Every scan produces a timestamped, self-contained output directory:

```
~/.recon-kit/output/
└── target_com_20260321_143055/
    │
    ├── REPORT.md                    ← Executive summary (Markdown)
    ├── recon.log                    ← Full timestamped operation log
    │
    ├── whois/
    │   └── whois.txt                ← Queried against root domain
    │
    ├── dns/
    │   ├── records.txt              ← All DNS record types
    │   └── axfr.txt                 ← Zone transfer result
    │
    ├── subdomains/
    │   ├── subfinder.txt
    │   ├── bruteforce.txt
    │   └── all.txt                  ← Deduplicated master list
    │
    ├── nmap/
    │   ├── quick.txt / quick.xml    ← Top 1000 ports + versions
    │   ├── full.txt                 ← All 65535 TCP (background)
    │   └── udp.txt                  ← UDP top 100 (root only)
    │
    ├── web/
    │   ├── whatweb.txt
    │   └── live_hosts.txt
    │
    ├── headers/
    │   ├── https.txt / http.txt
    │   └── security_audit.txt       ← Missing headers report
    │
    ├── cert/
    │   └── cert.txt
    │
    └── plugins/                     ← Output from custom plugins
```

<br>

---

## 📊 Sample Report

```markdown
# recon-kit Report — target.com

| Field    | Value                      |
|----------|----------------------------|
| Target   | target.com                 |
| Date     | 2026-03-21 14:30:55        |
| Duration | 142s                       |
| Distro   | kali (debian)              |
| Operator | krypthane | wavegxz-design  |

## Summary

| Metric              | Result |
|---------------------|--------|
| Open ports (quick)  | 7      |
| Subdomains found    | 23     |
| Missing sec headers | 3      |
| Modules run         | 6      |
```

<br>

---

## 📖 Documentation

| Topic | Link |
|-------|------|
| Installation guide | [docs/install.md](docs/install.md) |
| Module reference | [docs/modules.md](docs/modules.md) |
| Plugin development | [wiki/plugins](https://github.com/wavegxz-design/recon-kit/wiki/plugins) |
| AUTOFIX internals | [docs/autofix.md](docs/autofix.md) |
| Update system | [docs/update.md](docs/update.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |

<br>

---

## 🛣️ Roadmap

**v2.2**
- [ ] Shodan / Censys API integration module
- [ ] Nuclei vulnerability scanning module
- [ ] Telegram / Slack notification on scan complete

**v3.0**
- [ ] HTML report with charts and graphs
- [ ] Screenshot capture via gowitness
- [ ] Docker container release
- [ ] Web dashboard (local UI)
- [ ] Multi-target batch scanning

> 💡 Have an idea? [Open a feature request →](https://github.com/wavegxz-design/recon-kit/issues/new)

<br>

---

## 🤝 Contributing

Contributions are welcome — from bug reports to new modules and plugins.

**Before opening a PR, read [CONTRIBUTING.md](CONTRIBUTING.md).**

```bash
git clone https://github.com/YOUR_USERNAME/recon-kit
cd recon-kit
git checkout -b feat/your-feature-name
git commit -m "feat: clear description"
git push origin feat/your-feature-name
# → Open PR
```

**What we accept:**
- New recon modules or plugin templates
- Distro support expansions
- Bug fixes with reproduction steps
- Documentation improvements
- Performance optimizations

<br>

---

## 🔗 Related Projects

<table>
<tr>
<td>
<a href="https://github.com/wavegxz-design/NEXORA-TOOLKIT"><strong>NEXORA-TOOLKIT</strong></a>
<br><br>
Advanced modular ADB toolkit for Android device management. Built in Bash with full logging, multi-distro install, and menu-driven interface.
</td>
</tr>
</table>

<br>

---

## ⚖️ Legal Notice

> **Use only on systems you own or have explicit written authorization to test.**

Unauthorized reconnaissance may violate:
- Computer Fraud and Abuse Act (CFAA) — United States
- Computer Misuse Act (CMA) — United Kingdom
- Ley Federal de Telecomunicaciones y Radiodifusión — México
- Equivalent legislation in your jurisdiction

The author assumes no liability for misuse.

<br>

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:003b00,100:00ff41&height=120&section=footer" width="100%"/>

<br>

**Built with focus by [krypthane](https://github.com/wavegxz-design)**

[![Web](https://img.shields.io/badge/krypthane.workernova.workers.dev-00ff41?style=flat-square&logo=cloudflare&logoColor=white)](https://krypthane.workernova.workers.dev)
[![Telegram](https://img.shields.io/badge/Telegram-00ff41?style=flat-square&logo=telegram&logoColor=white)](https://t.me/Skrylakk)
[![Email](https://img.shields.io/badge/Proton_Mail-00ff41?style=flat-square&logo=protonmail&logoColor=white)](mailto:Workernova@proton.me)
[![GitHub](https://img.shields.io/badge/wavegxz--design-00ff41?style=flat-square&logo=github&logoColor=white)](https://github.com/wavegxz-design)

<br>

<sub>⭐ If recon-kit saved you time, drop a star — it helps more people find it.</sub>

</div>
