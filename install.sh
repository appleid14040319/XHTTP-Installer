#!/bin/bash
# NikVPN XHTTP Installer — Bootstrap
# Copyright (C) 2026 nikvpn-iran
# Based on XHTTP-Installer by avacocloud (GPL-3.0)
# License: GPL-3.0-only
# Repo: https://github.com/nikvpn-iran/NikVPN-xhttp-installer
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✘]${NC} $*"; exit 1; }

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
fi

# ============================================================
# Function to run Hiddify installation inside screen session
# ============================================================
install_hiddify_inside_screen() {
    local SCRIPT_PATH="$1"
    # Create a flag file to indicate Hiddify installation should run
    touch /tmp/install_hiddify.flag
    
    # Re-execute this script with a special flag inside screen
    screen -S xhttp -X stuff "export INSTALL_HIDDIFY=1 && bash $SCRIPT_PATH\n"
    sleep 2
}

# Check if this is the second run (after XHTTP installation)
if [[ "$INSTALL_HIDDIFY" == "1" ]]; then
    info "Continuing with HiddifyManager installation..."
    
    read -p "$(echo -e "${YELLOW}Do you want to install HiddifyManager panel for user management? (supports XHTTP/Vercel) [y/N]: ${NC}")" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Installing HiddifyManager panel..."
        
        apt-get update -qq
        apt-get install -y -qq curl wget ufw socat
        
        bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)
        
        if systemctl is-active --quiet hiddify-panel 2>/dev/null; then
            info "HiddifyManager installed successfully!"
            info "Access panel at: http://$(curl -s ifconfig.me 2>/dev/null):8080"
            echo ""
            echo -e "${GREEN}⚠️ IMPORTANT:${NC}"
            info "To use with your Vercel XHTTP config, add your Vercel domain as 'Relay Domain' in panel settings."
            info "Default login credentials will be shown after installation completes."
        else
            warn "HiddifyManager installation may have failed. Check manually."
            info "You can install later with: bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)"
        fi
    else
        info "Skipping HiddifyManager installation."
    fi
    
    rm -f /tmp/install_hiddify.flag
    info "All done! Type 'xhttp' to manage your XHTTP config."
    exit 0
fi

info "NikVPN XHTTP Installer — Bootstrap"
info "Cloning repository..."

# Install git if missing
if ! command -v git &>/dev/null; then
    warn "git not found. Installing..."
    apt-get update -qq && apt-get install -y -qq git
fi

REPO_DIR="/root/nikvpn-xhttp-installer"
if [[ -d "$REPO_DIR/.git" ]]; then
    warn "Directory $REPO_DIR already exists. Updating..."
    cd "$REPO_DIR"
    git pull origin main || git pull origin master || true
else
    if [[ -d "$REPO_DIR" ]]; then
        rm -rf "$REPO_DIR"
    fi
    git clone https://github.com/nikvpn-iran/NikVPN-xhttp-installer.git "$REPO_DIR"
fi

cd "$REPO_DIR"
chmod +x Deploy-Ubuntu.sh

# ============================================================
# Run Deploy-Ubuntu.sh and after it completes, ask about Hiddify
# ============================================================

# Check if we're already in screen
if [[ -n "$STY" ]]; then
    info "Already inside screen session: $STY"
    # Run Deploy-Ubuntu.sh
    info "Starting main installer..."
    ./Deploy-Ubuntu.sh
    
    # After Deploy-Ubuntu.sh finishes, ask about Hiddify
    echo ""
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}XHTTP installation completed!${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}Do you want to install HiddifyManager panel for user management? (supports XHTTP/Vercel) [y/N]: ${NC}")" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Installing HiddifyManager panel..."
        
        apt-get update -qq
        apt-get install -y -qq curl wget ufw socat
        
        bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)
        
        if systemctl is-active --quiet hiddify-panel 2>/dev/null; then
            info "HiddifyManager installed successfully!"
            info "Access panel at: http://$(curl -s ifconfig.me 2>/dev/null):8080"
            echo ""
            echo -e "${GREEN}⚠️ IMPORTANT:${NC}"
            info "To use with your Vercel XHTTP config, add your Vercel domain as 'Relay Domain' in panel settings."
            info "Default login credentials will be shown after installation completes."
        else
            warn "HiddifyManager installation may have failed. Check manually."
            info "You can install later with: bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)"
        fi
    else
        info "Skipping HiddifyManager installation. You can install later with:"
        echo "  bash <(curl -sSL https://raw.githubusercontent.com/hiddify/hiddify-manager/main/install.sh)"
    fi
    
    info "All done! Type 'xhttp' to manage your XHTTP config."
    
else
    # Not in screen - launch screen first
    info "Starting screen session for installation..."
    
    if ! command -v screen &>/dev/null; then
        info "Installing screen..."
        apt-get update -qq && apt-get install -y -qq screen
    fi
    
    # Kill existing xhttp screen session if exists
    if screen -ls 2>/dev/null | grep -q "\.xhttp\b"; then
        warn "Existing screen session 'xhttp' found. Removing it..."
        screen -S xhttp -X quit 2>/dev/null || true
        sleep 1
    fi
    
    info "Launching inside screen session 'xhttp'..."
    echo -e "  ${YELLOW}Detach anytime with Ctrl+A then D${NC}"
    echo -e "  ${YELLOW}If SSH drops, reconnect and run: screen -r xhttp${NC}"
    sleep 2
    
    # Launch this same script inside screen
    exec screen -S xhttp bash -c "export TERM=xterm-256color; bash '$0'"
fi
