# Arda-Tech PPA — Official Debian & Ubuntu APT Repository

<p align="center">
  <img src="https://raw.githubusercontent.com/Antux912012/arda-tech/main/logo.svg" width="96" height="96" alt="Arda Tech Emblem" />
</p>

<p align="center">
  <strong>Official GPG-Signed APT / PPA Repository for Debian, Ubuntu, Linux Mint, and Derivatives</strong><br>
  Hosted on GitHub Pages at: <a href="https://antux912012.github.io/arda-tech-ppa"><strong>https://antux912012.github.io/arda-tech-ppa</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Debian-Bookworm%20%7C%20Trixie%20%7C%20Sid-d70a53?logo=debian" alt="Debian" />
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04%2B-E95420?logo=ubuntu" alt="Ubuntu" />
  <img src="https://img.shields.io/badge/GPG%20Signed-RSA%204096--bit-success" alt="GPG Signed" />
  <img src="https://img.shields.io/badge/Packages-10%20Apps-informational" alt="10 Packages" />
</p>

---

## ⚡ Quick 1-Line Setup

Add the **Arda-Tech PPA** and GPG signing key on any Debian, Ubuntu, Linux Mint, Pop!_OS, or Zorin OS system with a single command:

```bash
curl -fsSL https://antux912012.github.io/arda-tech-ppa/setup.sh | sudo bash
```

### Manual Step-by-Step Setup

If you prefer to configure APT manually:

```bash
# 1. Install the Arda-Tech GPG signing key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://antux912012.github.io/arda-tech-ppa/KEY.gpg | sudo tee /etc/apt/keyrings/arda-tech.gpg >/dev/null

# 2. Add the Arda-Tech PPA repository
echo "deb [signed-by=/etc/apt/keyrings/arda-tech.gpg] https://antux912012.github.io/arda-tech-ppa stable main" | sudo tee /etc/apt/sources.list.d/arda-tech.list

# 3. Update APT index
sudo apt update
```

Supported distribution suites in `dists/`: `stable`, `bookworm`, `trixie`, `sid`, `noble`, `jammy`.

---

## 📦 Available Packages in `arda-tech-ppa`

Once the PPA is enabled, install any application directly via `sudo apt install <package>`:

| Package | Version | Arch | Install Command | Description | Source Repo |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`mithrandir`** | `0.4.1` | `all` | `sudo apt install mithrandir` | Modern GNU/Linux System Cleaner, Optimizer, ClamAV Anti-Malware, and AI Diagnostics (Python / GTK4 / Libadwaita) | [Antux912012/mithrandir](https://github.com/Antux912012/mithrandir) |
| **`mithrandir-rs`** | `0.4.1` | `amd64` | `sudo apt install mithrandir-rs` | Blazing-fast Rust edition of Mithrandir with GTK4/Libadwaita, Stacer-grade telemetry, Smart Boost, and local LLM manager | [Antux912012/mithrandir-rs](https://github.com/Antux912012/mithrandir-rs) |
| **`vingilot`** | `0.1.6-1` | `amd64` | `sudo apt install vingilot` | Privacy-first native GTK4, Libadwaita & WebKitGTK 6.0 web browser with Wayland & Vulkan acceleration | [Antux912012/Vingilot](https://github.com/Antux912012/Vingilot) |
| **`vingilot-estel`** | `0.1.0-alpha-1` | `amd64` | `sudo apt install vingilot-estel` | Next-generation GTK4 & Libadwaita web browser powered by Mozilla Servo & WebKit hybrid engine | [Antux912012/Vingilot](https://github.com/Antux912012/Vingilot) |
| **`imladris`** | `0.4.0` | `amd64` | `sudo apt install imladris` | Native GTK4 & Libadwaita Markdown Editor & Polyglot Studio with GtkSourceView 5, live preview, AI assistance & MCP server | [Antux912012/imladris-next-md-editor](https://github.com/Antux912012/imladris-next-md-editor) |
| **`cachy-kernel-updater`** | `1.1.2` | `all` | `sudo apt install cachy-kernel-updater` | Automated graphical & CLI forge to fetch, tune, compile, and install CachyOS BORE kernels on Debian | [Antux912012/debian-cachy-kernel-updater](https://github.com/Antux912012/debian-cachy-kernel-updater) |
| **`yt-comment-extractor`** | `0.6` | `all` | `sudo apt install yt-comment-extractor` | Native GTK4 & Libadwaita GUI tool powered by `yt-dlp` to extract, filter, and analyze YouTube comments | [Antux912012/YT-Comment-Extractor-GTK](https://github.com/Antux912012/YT-Comment-Extractor-GTK) |
| **`yt-comment-extractor-service`** | `0.6` | `all` | `sudo apt install yt-comment-extractor-service` | Background web dashboard and system tray daemon for YouTube Comment Extractor | [Antux912012/YT-Comment-Extractor-GTK](https://github.com/Antux912012/YT-Comment-Extractor-GTK) |
| **`sulimo`** | `0.2.0` | `amd64` | `sudo apt install sulimo` | *Súlimo (Arda's Breath)* C11 hardware capability probe (`arda-probe`) and runtime optimization policy engine | [Antux912012/arda-tech](https://github.com/Antux912012/arda-tech) |
| **`vfs5011-linux-fix`** | `1.0.0` | `all` | `sudo apt install vfs5011-linux-fix` | Automated Linux driver patcher and installer for Validity VFS5011 fingerprint sensors (`138a:0011`, `138a:0017`, `138a:0018`) | [Antux912012/vfs5011-linux-fix](https://github.com/Antux912012/vfs5011-linux-fix) |

### Install Everything at Once

```bash
sudo apt install mithrandir mithrandir-rs vingilot vingilot-estel imladris cachy-kernel-updater yt-comment-extractor yt-comment-extractor-service sulimo vfs5011-linux-fix
```

---

## 🔒 Cryptographic Verification (GPG)

All `Release` and `InRelease` manifests are signed with the **Arda Tech** 4096-bit RSA GPG key:

- **Key ID:** `CF9DC18F75B6C72B`
- **Fingerprint:** `4C4C 7DAF 16CE 9706 0FAF 10AE CF9D C18F 75B6 C72B`
- **Public Key (Binary):** [`KEY.gpg`](https://antux912012.github.io/arda-tech-ppa/KEY.gpg)
- **Public Key (ASCII Armored):** [`KEY.asc`](https://antux912012.github.io/arda-tech-ppa/KEY.asc)

---

## 🔗 Related Repository

- **[Arda-Tech Flatpak Sanctum (`Antux912012/arda-tech`)](https://github.com/Antux912012/arda-tech)**: Official OSTree / Flatpak repository for sandboxed installations across all Linux distributions.
