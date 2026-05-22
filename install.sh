#!/bin/bash
# NikVPN XHTTP Installer — Complete Installation
# Installs XHTTP + Vercel + HiddifyManager v11 together
# Copyright (C) 2026 nikvpn-iran
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✘]${NC} $*"; exit 1; }
step()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
title() { echo -e "${BLUE}➜${NC} ${YELLOW}$*${NC}"; }

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
fi

# ============================================================
# Function: Install XHTTP + Vercel (without screen)
# ============================================================
install_xhttp() {
    step
    title "Installing XHTTP + Vercel Relay..."
    step
    
    # Install git if missing
    if ! command -v git &>/dev/null; then
        info "Installing git..."
        apt-get update -qq && apt-get install -y -qq git
    fi
    
    REPO_DIR="/root/nikvpn-xhttp-installer"
    if [[ -d "$REPO_DIR/.git" ]]; then
        warn "Directory $REPO_DIR exists. Updating..."
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
    
    # Run Deploy-Ubuntu.sh WITHOUT screen by setting environment variable
    info "Running XHTTP installer (no screen mode)..."
    export XHTTP_NO_SCREEN=1
    ./Deploy-Ubuntu.sh
    
    # Save XHTTP output for later use
    if [ -f /root/xhttp-configs.txt ]; then
        cp /root/xhttp-configs.txt /tmp/xhttp-configs.txt 2>/dev/null || true
    fi
    
    info "XHTTP + Vercel installation completed!"
}

# ============================================================
# Function: Install HiddifyManager v11
# ============================================================
install_hiddify() {
    step
    title "Installing HiddifyManager v11..."
    step
    
    # Install prerequisites
    info "Installing prerequisites..."
    apt-get update -qq
    apt-get install -y -qq curl wget sudo socat ufw
    
    # Wait a bit for system to settle
    sleep 3
    
    # Install latest HiddifyManager (v11)
    info "Downloading and installing HiddifyManager v11..."
    bash <(curl -sSL https://i.hiddify.com/release)
    
    # Wait for installation to complete
    sleep 10
    
    # Check installation
    if systemctl is-active --quiet hiddify-panel 2>/dev/null; then
        local SERVER_IP
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
        echo ""
        info "HiddifyManager v11 installed successfully!"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}    HiddifyPanel Access: http://${SERVER_IP}:8080${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "  1. Open panel in browser: http://${SERVER_IP}:8080"
        echo "  2. Login with credentials shown above"
        echo "  3. Go to 'Domains' → Add your Vercel domain as 'Relay Domain'"
        echo "  4. Go to 'Users' → Create users with traffic limits"
    else
        warn "HiddifyManager installation might have issues."
        info "You can install manually later: bash <(curl -sSL https://i.hiddify.com/release)"
    fi
}

# ============================================================
# Main installation (runs everything)
# ============================================================

clear
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     NikVPN Complete Installer - XHTTP + HiddifyManager     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This installer will:${NC}"
echo "  1. Install XHTTP + Vercel Relay"
echo "  2. Install HiddifyManager v11 (User Management + Traffic Limits)"
echo "  3. Configure everything to work together"
echo ""
echo -e "${YELLOW}⚠️ IMPORTANT NOTES:${NC}"
echo "  • Make sure your domain DNS points to this server"
echo "  • Installation takes 5-10 minutes"
echo "  • If SSH disconnects, run: screen -r nikvpn"
echo ""
read -p "$(echo -e "${GREEN}Press Enter to start installation...${NC}")" 

# Create a flag file to track progress
PROGRESS_FILE="/tmp/install_progress.log"

# Step 1: Install XHTTP
install_xhttp
echo "XHTTP_DONE" >> "$PROGRESS_FILE"

# Step 2: Install HiddifyManager
install_hiddify
echo "HIDDIFY_DONE" >> "$PROGRESS_FILE"

# Step 3: Final configuration
step
title "Final Configuration"
step

echo ""
info "Both installations completed successfully!"
echo ""

echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    ✓ INSTALLATION COMPLETE ✓${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📌 XHTTP Info:${NC}"
if [ -f /tmp/xhttp-configs.txt ]; then
    cat /tmp/xhttp-configs.txt
else
    echo "  • Check /root/xhttp-configs.txt for config"
    echo "  • Type 'xhttp' command to manage"
fi
echo ""
echo -e "${YELLOW}📌 HiddifyManager Info:${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "  • Panel URL: http://${SERVER_IP}:8080"
echo "  • Manage users, traffic limits, IP restrictions"
echo "  • Add your Vercel domain as 'Relay Domain'"
echo ""
echo -e "${YELLOW}📌 To combine both:${NC}"
echo "  1. Open Hiddify panel"
echo "  2. Go to 'Domains' → Add your Vercel project domain"
echo "  3. Create users with traffic limits"
echo "  4. Users will automatically use Vercel relay"
echo ""

info "All done! Your server is ready."

# Clean up
rm -f /tmp/install_progress.log 2>/dev/null || true
