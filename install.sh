#!/bin/bash
# NikVPN Complete Installer - XHTTP + HiddifyManager
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/nikvpn-iran/NikVPN-xhttp-installer/main/install.sh)
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

if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root."
fi

# ============================================================
# Variables
# ============================================================
SCREEN_NAME="nikvpn"
STAGE_FILE="/tmp/nikvpn_stage"
XHTTP_REPO="https://github.com/nikvpn-iran/NikVPN-xhttp-installer.git"

# ============================================================
# Function: Install HiddifyManager
# ============================================================
install_hiddify() {
    step
    info "Installing HiddifyManager v11..."
    
    apt-get update -qq
    apt-get install -y -qq curl wget sudo socat ufw
    
    info "Downloading HiddifyManager..."
    bash <(curl -sSL https://i.hiddify.com/release)
    
    sleep 5
    if systemctl is-active --quiet hiddify-panel 2>/dev/null; then
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
        echo ""
        info "HiddifyManager installed!"
        echo -e "${GREEN}Panel: http://${SERVER_IP}:8080${NC}"
        echo ""
        info "Next steps in Hiddify panel:"
        echo "  1. Login with credentials shown above"
        echo "  2. Go to 'Domains' → Add your Vercel domain as 'Relay Domain'"
        echo "  3. Go to 'Users' → Create users with traffic limits"
    else
        warn "HiddifyManager installation failed. Run manually: bash <(curl -sSL https://i.hiddify.com/release)"
    fi
}

# ============================================================
# Function: Install XHTTP (runs inside screen)
# ============================================================
install_xhttp() {
    info "Cloning XHTTP repository..."
    
    if ! command -v git &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq git
    fi
    
    cd /root
    if [ -d "/root/nikvpn-xhttp-installer" ]; then
        rm -rf /root/nikvpn-xhttp-installer
    fi
    
    git clone "$XHTTP_REPO" /root/nikvpn-xhttp-installer
    cd /root/nikvpn-xhttp-installer
    chmod +x Deploy-Ubuntu.sh
    
    info "Starting XHTTP installation..."
    
    # Create a script to run inside screen that will also trigger Hiddify
    cat > /tmp/run_xhttp.sh << 'INNERSCRIPT'
#!/bin/bash
cd /root/nikvpn-xhttp-installer
export TERM=xterm-256color
./Deploy-Ubuntu.sh

# After XHTTP completes, mark it done and trigger Hiddify
echo "XHTTP_COMPLETE" > /tmp/xhttp_done
INNERSCRIPT
    
    chmod +x /tmp/run_xhttp.sh
    
    # Kill existing screen session if exists
    screen -S "$SCREEN_NAME" -X quit 2>/dev/null || true
    sleep 1
    
    # Run in screen
    screen -S "$SCREEN_NAME" -dm bash /tmp/run_xhttp.sh
    
    info "XHTTP installation started in screen session '$SCREEN_NAME'"
    echo -e "${YELLOW}To watch progress: screen -r $SCREEN_NAME${NC}"
    echo -e "${YELLOW}To detach: Ctrl+A then D${NC}"
}

# ============================================================
# Main Installation
# ============================================================
clear
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     NikVPN Complete Installer - XHTTP + HiddifyManager     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This installer will:${NC}"
echo "  1. Install XHTTP + Vercel Relay"
echo "  2. Install HiddifyManager v11"
echo ""
echo -e "${YELLOW}⚠️ Make sure your domain DNS points to this server before continuing!${NC}"
echo ""

# Check if screen is installed
if ! command -v screen &>/dev/null; then
    info "Installing screen..."
    apt-get update -qq && apt-get install -y -qq screen
fi

# Ask for domain
read -p "$(echo -e "${GREEN}Enter your domain (e.g., sub.example.com): ${NC}")" DOMAIN
if [[ -z "$DOMAIN" ]]; then
    err "Domain is required!"
fi

# Save domain for later use
echo "$DOMAIN" > /tmp/nikvpn_domain

# Start XHTTP installation
install_xhttp

# Wait for XHTTP to complete
step
info "Waiting for XHTTP installation to complete..."
echo -e "${YELLOW}This may take 5-10 minutes...${NC}"
echo ""

while true; do
    if [ -f "/tmp/xhttp_done" ]; then
        info "XHTTP installation completed!"
        break
    fi
    
    # Check if screen session is still running
    if ! screen -ls 2>/dev/null | grep -q "\.$SCREEN_NAME\b"; then
        # Screen ended but no done flag - might have crashed
        if [ ! -f "/tmp/xhttp_done" ]; then
            warn "XHTTP installation may have failed."
            echo "Checking screen output..."
            screen -ls
            read -p "Continue with Hiddify installation anyway? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                err "Installation aborted by user."
            fi
            break
        fi
    fi
    
    echo -n "."
    sleep 10
done

# Clean up
rm -f /tmp/run_xhttp.sh 2>/dev/null || true
rm -f /tmp/xhttp_done 2>/dev/null || true

# Install HiddifyManager
install_hiddify

# Final message
step
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
info "Your Vercel XHTTP is ready!"
info "HiddifyManager panel is ready!"
echo ""
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo -e "${YELLOW}📌 Hiddify Panel: http://${SERVER_IP}:8080${NC}"
echo -e "${YELLOW}📌 XHTTP Config: Type 'xhttp' command${NC}"
echo ""

# Clean up
rm -f /tmp/nikvpn_stage 2>/dev/null || true
rm -f /tmp/nikvpn_domain 2>/dev/null || true

info "Done! Your server is ready."
