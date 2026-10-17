#!/usr/bin/env bash

# ============================================================
# BLACK EYE — AUTO INSTALLER
# Detects OS + Arch, installs all dependencies automatically
# ============================================================

set -o pipefail

# Colors
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
cyan='\e[96m'
blue='\e[94m'
magenta='\e[95m'
purple='\e[35m'
white='\e[97m'
reset='\e[0m'
bold='\e[1m'

# ============================================================
# UTILITY FUNCTIONS
# ============================================================
info()    { echo -e "${cyan}[*]${reset} $*"; }
success() { echo -e "${green}[✓]${reset} $*"; }
warn()    { echo -e "${yellow}[!]${reset} $*"; }
error()   { echo -e "${red}[✗]${reset} $*"; }
step()    { echo -e "\n${magenta}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"; echo -e "${bold}${cyan}▶ $*${reset}"; echo -e "${magenta}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"; }

# ============================================================
# DETECT OS + PACKAGE MANAGER + ARCH
# ============================================================
detect_system() {
    step "Detecting system"

    # Architecture
    ARCH_RAW=$(uname -m)
    case "$ARCH_RAW" in
        aarch64|arm64)  ARCH="arm64" ;;
        armv7l|armv8l)  ARCH="arm"   ;;
        x86_64|amd64)   ARCH="amd64" ;;
        i686|i386)      ARCH="386"   ;;
        *)              ARCH="arm64" ;;
    esac
    info "Architecture: ${bold}$ARCH_RAW${reset} → ${bold}$ARCH${reset}"

    # OS / Package Manager
    if [[ -d /data/data/com.termux ]]; then
        OS="termux"
        PKG_MGR="pkg"
        INSTALL_CMD="pkg install -y"
        UPDATE_CMD="pkg update -y"
        PREFIX_BIN="$PREFIX/bin"
    elif command -v apt >/dev/null 2>&1; then
        OS="debian"
        PKG_MGR="apt"
        INSTALL_CMD="sudo apt install -y"
        UPDATE_CMD="sudo apt update -y"
        PREFIX_BIN="/usr/local/bin"
    elif command -v dnf >/dev/null 2>&1; then
        OS="fedora"
        PKG_MGR="dnf"
        INSTALL_CMD="sudo dnf install -y"
        UPDATE_CMD="sudo dnf check-update || true"
        PREFIX_BIN="/usr/local/bin"
    elif command -v pacman >/dev/null 2>&1; then
        OS="arch"
        PKG_MGR="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
        UPDATE_CMD="sudo pacman -Sy"
        PREFIX_BIN="/usr/local/bin"
    elif command -v brew >/dev/null 2>&1; then
        OS="macos"
        PKG_MGR="brew"
        INSTALL_CMD="brew install"
        UPDATE_CMD="brew update"
        PREFIX_BIN="/usr/local/bin"
    else
        OS="unknown"
        PKG_MGR=""
        error "Unsupported OS. Install manually: php curl wget sqlite jq"
        exit 1
    fi

    info "OS: ${bold}$OS${reset}"
    info "Package manager: ${bold}$PKG_MGR${reset}"
}

# ============================================================
# PACKAGE INSTALL WITH VERIFY + RETRY
# ============================================================
install_pkg() {
    local cmd="$1"       # binary to check
    local pkg_termux="$2"
    local pkg_debian="$3"
    local pkg_fedora="$4"
    local pkg_arch="$5"
    local pkg_macos="$6"

    # Skip if binary already exists
    if command -v "$cmd" >/dev/null 2>&1; then
        success "$cmd already installed ($(command -v $cmd))"
        return 0
    fi

    # Choose package name based on OS
    local pkg_name=""
    case "$OS" in
        termux)  pkg_name="$pkg_termux" ;;
        debian)  pkg_name="${pkg_debian:-$pkg_termux}" ;;
        fedora)  pkg_name="${pkg_fedora:-$pkg_debian:-$pkg_termux}" ;;
        arch)    pkg_name="${pkg_arch:-$pkg_termux}" ;;
        macos)   pkg_name="${pkg_macos:-$pkg_termux}" ;;
        *)       pkg_name="$pkg_termux" ;;
    esac

    [[ -z "$pkg_name" ]] && { warn "No package name for $cmd on $OS"; return 1; }

    info "Installing $pkg_name..."

    # Retry 2 times
    local attempt=0
    while [[ $attempt -lt 2 ]]; do
        attempt=$((attempt + 1))

        case "$OS" in
            termux) pkg install "$pkg_name" -y 2>&1 | tail -3 ;;
            debian) sudo apt install "$pkg_name" -y 2>&1 | tail -3 ;;
            fedora) sudo dnf install "$pkg_name" -y 2>&1 | tail -3 ;;
            arch)   sudo pacman -S "$pkg_name" --noconfirm 2>&1 | tail -3 ;;
            macos)  brew install "$pkg_name" 2>&1 | tail -3 ;;
        esac

        if command -v "$cmd" >/dev/null 2>&1; then
            success "$cmd installed ($(command -v $cmd))"
            return 0
        fi

        [[ $attempt -lt 2 ]] && warn "Attempt $attempt failed, retrying..."
    done

    error "$cmd install FAILED after 2 attempts"
    return 1
}

# ============================================================
# CLOUDFLARED SPECIAL INSTALL (with binary fallback)
# ============================================================
install_cloudflared() {
    if command -v cloudflared >/dev/null 2>&1; then
        success "cloudflared already installed ($(cloudflared --version 2>/dev/null | head -1))"
        return 0
    fi

    info "Installing cloudflared..."

    # Try package manager first
    case "$OS" in
        termux) pkg install cloudflared -y >/dev/null 2>&1 || true ;;
        debian) sudo apt install cloudflared -y >/dev/null 2>&1 || true ;;
        *) ;;
    esac

    if command -v cloudflared >/dev/null 2>&1; then
        success "cloudflared installed via $PKG_MGR"
        return 0
    fi

    # Fallback: download binary
    warn "Package manager failed — downloading binary for $ARCH..."

    local cdn_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"

    # macOS uses different binary
    if [[ "$OS" == "macos" ]]; then
        if brew install cloudflared >/dev/null 2>&1; then
            success "cloudflared installed via brew"
            return 0
        fi
        error "cloudflared install failed on macOS. Install: brew install cloudflared"
        return 1
    fi

    # Linux/Termux: download binary
    local tmp_bin="/tmp/cloudflared.$$"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$cdn_url" -o "$tmp_bin" || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$cdn_url" -O "$tmp_bin" || true
    fi

    if [[ -s "$tmp_bin" ]]; then
        chmod +x "$tmp_bin"
        # Try to move to PREFIX/bin or /usr/local/bin
        if [[ -w "$PREFIX_BIN" ]] 2>/dev/null || sudo -n true 2>/dev/null; then
            sudo mv "$tmp_bin" "$PREFIX_BIN/cloudflared" 2>/dev/null || mv "$tmp_bin" "$PREFIX_BIN/cloudflared" 2>/dev/null || true
        fi
        # If still not in PATH, try home dir
        if ! command -v cloudflared >/dev/null 2>&1; then
            mkdir -p "$HOME/.local/bin"
            mv "$tmp_bin" "$HOME/.local/bin/cloudflared"
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi

    if command -v cloudflared >/dev/null 2>&1; then
        success "cloudflared installed at $(command -v cloudflared)"
        return 0
    fi

    error "cloudflared install failed!"
    echo -e "${yellow}  Manual install:${reset}"
    echo -e "  wget $cdn_url -O cloudflared && chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/"
    return 1
}

# ============================================================
# MAIN INSTALL FLOW
# ============================================================
show_banner() {
    clear
    echo -e "${red}    ██████╗ ██╗      █████╗  ██████╗██╗  ██╗    ███████╗██╗   ██╗███████╗${reset}"
    echo -e "${yellow}    ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝    ██╔════╝╚██╗ ██╔╝██╔════╝${reset}"
    echo -e "${green}    ██████╔╝██║     ███████║██║     █████╔╝     █████╗   ╚████╔╝ █████╗  ${reset}"
    echo -e "${cyan}    ██╔══██╗██║     ██╔══██║██║     ██╔═██╗     ██╔══╝    ╚██╔╝  ██╔══╝  ${reset}"
    echo -e "${blue}    ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗    ███████╗   ██║   ███████╗${reset}"
    echo -e "${purple}    ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝   ╚═╝   ╚══════╝${reset}"
    echo ""
    echo -e "${yellow}              ⚡ AUTO INSTALLER ⚡${reset}"
    echo -e "${cyan}  Created by:${reset} ${green}ATHEX${reset} ${cyan}YouTube:${reset} ${red}@inziXploit444${reset}"
    echo ""
}

main() {
    show_banner
    detect_system

    # ========================================================
    # STEP 1: Update package list
    # ========================================================
    step "Updating package lists"
    if [[ -n "$UPDATE_CMD" ]]; then
        info "Running: $UPDATE_CMD"
        eval "$UPDATE_CMD" >/dev/null 2>&1 || warn "Update failed — continuing anyway"
        success "Package lists updated"
    fi

    # ========================================================
    # STEP 2: Core packages (REQUIRED)
    # ========================================================
    step "Installing core packages"

    # PHP (CRITICAL)
    if ! install_pkg php php php php php php; then
        echo ""
        error "PHP install failed — cannot continue"
        echo -e "${yellow}Try manually:${reset}"
        echo -e "  Termux:  pkg install php"
        echo -e "  Debian:  sudo apt install php"
        echo -e "  Fedora:  sudo dnf install php"
        echo -e "  Arch:    sudo pacman -S php"
        echo -e "  macOS:   brew install php"
        exit 1
    fi

    # Verify PHP actually runs
    if ! php -v >/dev/null 2>&1; then
        error "PHP installed but not executable!"
        exit 1
    fi
    success "PHP working: $(php -v | head -1)"

    # curl
    install_pkg curl curl curl curl curl curl || warn "curl missing — some features may not work"

    # wget
    install_pkg wget wget wget wget wget wget || warn "wget missing"

    # sqlite3 (package name differs by OS)
    install_pkg sqlite3 sqlite sqlite3 sqlite sqlite sqlite || warn "sqlite3 missing — DB logging disabled"

    # jq
    install_pkg jq jq jq jq jq jq || warn "jq missing — falling back to grep parsing"

    # inotify-tools (inotifywait)
    install_pkg inotifywait inotify-tools inotify-tools inotify-tools inotify-tools inotify-tools \
        || warn "inotifywait missing — using slow polling mode"

    # openssh (ssh for serveo)
    install_pkg ssh openssh openssh-client openssh openssh openssh || warn "ssh missing — option 3 disabled"

    # ========================================================
    # STEP 3: Optional packages (Termux-only)
    # ========================================================
    if [[ "$OS" == "termux" ]]; then
        step "Installing Termux-specific packages"
        install_pkg termux-toast termux-api termux-api termux-api termux-api termux-api \
            || warn "termux-api missing — no toast/vibrate"
    fi

    # ========================================================
    # STEP 4: Cloudflared (special handling)
    # ========================================================
    step "Installing cloudflared (HTTPS tunnel)"
    install_cloudflared || warn "cloudflared failed — use option 3 (Serveo) instead"

    # ========================================================
    # STEP 5: Final verification
    # ========================================================
    step "Final verification"

    local missing=()
    for cmd in php curl wget; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "$cmd: $(command -v $cmd)"
        else
            error "$cmd: MISSING"
            missing+=("$cmd")
        fi
    done

    for cmd in sqlite3 jq inotifywait cloudflared ssh; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "$cmd: $(command -v $cmd)"
        else
            warn "$cmd: missing (optional)"
        fi
    done

    # ========================================================
    # DONE
    # ========================================================
    echo ""
    echo -e "${green}╔══════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${green}║                                                                  ║${reset}"
    echo -e "${green}║              ✅ INSTALLATION COMPLETE! ✅                        ║${reset}"
    echo -e "${green}║                                                                  ║${reset}"
    echo -e "${green}╚══════════════════════════════════════════════════════════════════╝${reset}"
    echo ""

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing required: ${missing[*]}"
        echo -e "${yellow}Fix manually and re-run install.sh${reset}"
    else
        success "All required packages installed!"
    fi

    echo ""
    echo -e "${bold}${cyan}🎯 NEXT STEP:${reset}"
    echo -e "  ${green}bash run.sh${reset}"
    echo ""
    echo -e "${cyan}Then choose:${reset}"
    echo -e "  ${green}[1]${reset} Localhost     (same device only)"
    echo -e "  ${green}[2]${reset} Cloudflared   (HTTPS — recommended)"
    echo -e "  ${green}[3]${reset} Serveo.net    (SSH tunnel)"
    echo ""
}

# ============================================================
# RUN
# ============================================================
main "$@"
