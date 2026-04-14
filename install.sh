#!/bin/bash

# ============================================================
#   Quip Network — Auto Node Installer
#   by @0xDarkSeidBull | republicstats.xyz
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
  echo -e "${CYAN}"
  echo "  ██████  ██    ██ ██ ██████      ███    ██  ██████  ██████  ███████ "
  echo " ██    ██ ██    ██ ██ ██   ██     ████   ██ ██    ██ ██   ██ ██      "
  echo " ██    ██ ██    ██ ██ ██████      ██ ██  ██ ██    ██ ██   ██ █████   "
  echo " ██ ▄▄ ██ ██    ██ ██ ██          ██  ██ ██ ██    ██ ██   ██ ██      "
  echo "  ██████   ██████  ██ ██          ██   ████  ██████  ██████  ███████ "
  echo "     ▀▀                                                               "
  echo -e "${NC}"
  echo -e "${BOLD}  Quip Network — One-Click Node Installer${NC}"
  echo -e "  by ${CYAN}@0xDarkSeidBull${NC} | ${CYAN}republicstats.xyz${NC}"
  echo ""
}

step() { echo -e "\n${GREEN}[+]${NC} ${BOLD}$1${NC}"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }

clear
banner

echo -e "${BOLD}This script will automatically:${NC}"
echo "  • Install Docker (if not already installed)"
echo "  • Open required ports (20049 UDP/TCP)"
echo "  • Clone the Quip node repository"
echo "  • Generate your node config"
echo "  • Start the node"
echo "  • Install auto-update cron job"
echo ""
echo -e "${YELLOW}Press ENTER to continue or Ctrl+C to cancel...${NC}"
read -r

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Step 1: Your Details${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -rp "$(echo -e "${CYAN}Enter your handle${NC} (e.g. CryptoUser): ")" HANDLE
[[ -z "$HANDLE" ]] && error "Handle cannot be empty."

read -rp "$(echo -e "${CYAN}Enter your EVM wallet address${NC} (0x...): ")" WALLET
[[ "$WALLET" != 0x* ]] && error "Wallet address must start with 0x"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  GitLab Token Required${NC}"
echo ""
echo -e "  Follow these steps to get your token:"
echo ""
echo -e "  1. Open this URL in your browser:"
echo -e "     ${CYAN}https://gitlab.com/-/user_settings/personal_access_tokens${NC}"
echo ""
echo -e "  2. Token name: ${YELLOW}quip-node${NC} (or anything you like)"
echo -e "  3. Expiration date: leave blank"
echo -e "  4. Scope: check only ${YELLOW}read_repository${NC}"
echo -e "  5. Click 'Create personal access token'"
echo -e "  6. Copy the token immediately — it will only be shown once!"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "$(echo -e "${CYAN}Once your token is ready, press ENTER to paste it...${NC}")"
echo ""
read -rp "$(echo -e "${CYAN}Paste your GitLab token: ${NC}")" GITLAB_TOKEN
[[ -z "$GITLAB_TOKEN" ]] && error "GitLab token cannot be empty."

read -rp "$(echo -e "${CYAN}Enter your VPS public IP address${NC}: ")" PUBLIC_IP
[[ -z "$PUBLIC_IP" ]] && error "IP address cannot be empty."

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Your node will be registered as:"
echo -e "  ${YELLOW}${HANDLE} - ${WALLET}${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -rp "$(echo -e "${CYAN}Everything looks correct? Continue? (y/N): ${NC}")" CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && error "Setup cancelled."

step "Checking Docker..."
if ! command -v docker &> /dev/null; then
  warn "Docker not found — installing..."
  apt-get update -qq
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker && systemctl start docker
  apt-get install -y -qq docker-compose-plugin
  ok "Docker installed successfully"
else
  ok "Docker already installed: $(docker --version)"
fi

if ! docker compose version &> /dev/null; then
  warn "Installing docker-compose-plugin..."
  apt-get install -y -qq docker-compose-plugin
fi
ok "Docker Compose ready"

step "Opening ports (20049 UDP/TCP)..."
if command -v ufw &> /dev/null; then
  ufw allow 20049/udp > /dev/null 2>&1 || true
  ufw allow 20049/tcp > /dev/null 2>&1 || true
  ok "Firewall ports opened"
else
  warn "UFW not found — make sure port 20049 is open on your VPS firewall"
fi

step "Cloning Quip node repository..."
INSTALL_DIR="$HOME/nodes.quip.network"

if [[ -d "$INSTALL_DIR" ]]; then
  warn "Directory already exists: $INSTALL_DIR"
  read -rp "$(echo -e "${YELLOW}Delete and re-clone? (y/N): ${NC}")" RECLONE
  if [[ "$RECLONE" == "y" || "$RECLONE" == "Y" ]]; then
    rm -rf "$INSTALL_DIR"
  else
    warn "Using existing directory..."
  fi
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  ENCODED_TOKEN=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${GITLAB_TOKEN}', safe=''))")
  git clone "https://oauth2:${ENCODED_TOKEN}@gitlab.com/quip.network/nodes.quip.network.git" "$INSTALL_DIR" \
    || error "Clone failed — check your GitLab token and try again"
  ok "Repository cloned to: $INSTALL_DIR"
else
  ok "Using existing repository"
fi

cd "$INSTALL_DIR"

step "Generating node config..."
SECRET=$(openssl rand -hex 32)
cp data/config.cpu.toml data/config.toml
sed -i "s|secret = .*|secret = \"${SECRET}\"|" data/config.toml
sed -i "s|public_host = .*|public_host = \"${PUBLIC_IP}\"|" data/config.toml
sed -i "s|node_name = .*|node_name = \"${HANDLE} - ${WALLET}\"|" data/config.toml
sed -i "s|auto_mine = .*|auto_mine = true|" data/config.toml
sed -i "s|tofu = .*|tofu = true|" data/config.toml
ok "config.toml generated"

step "Setting up environment..."
if [[ -f "env.example" ]]; then
  cp env.example .env
  sed -i "s|CERT_EMAIL=.*|CERT_EMAIL=|" .env
  ok ".env ready"
else
  touch .env
  warn "env.example not found — created empty .env"
fi

step "Checking for port conflicts (80/443)..."
PORT80=$(ss -tlnp 2>/dev/null | grep ':80 ' || true)
PORT443=$(ss -tlnp 2>/dev/null | grep ':443 ' || true)
if [[ -n "$PORT80" || -n "$PORT443" ]]; then
  warn "Ports 80/443 are in use — commenting them out in docker-compose.yml..."
  sed -i 's|^\s*- "80:80"|      # - "80:80"|' docker-compose.yml
  sed -i 's|^\s*- "443:443"|      # - "443:443"|' docker-compose.yml
  ok "Port conflict resolved"
else
  ok "Ports 80/443 are free"
fi

step "Starting node..."
docker compose --profile cpu pull -q
docker compose --profile cpu up -d
ok "Node started!"

step "Installing auto-update cron job..."
if [[ -f "cron.sh" ]]; then
  chmod +x cron.sh
  ./cron.sh --install
  ok "Auto-update cron job installed"
else
  warn "cron.sh not found — auto-updates will need to be set up manually"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅  YOUR NODE IS LIVE!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Node Name:${NC}  ${YELLOW}${HANDLE} - ${WALLET}${NC}"
echo -e "  ${BOLD}Public IP:${NC}  ${YELLOW}${PUBLIC_IP}${NC}"
echo -e "  ${BOLD}Directory:${NC}  ${YELLOW}${INSTALL_DIR}${NC}"
echo ""
echo -e "  ${BOLD}To view logs:${NC}"
echo -e "  ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f cpu${NC}"
echo ""
echo -e "  ${BOLD}Network stats:${NC}   ${CYAN}https://republicstats.xyz${NC}"
echo -e "  ${BOLD}Quest dashboard:${NC} ${CYAN}https://quest.quip.network/airdrop${NC}"
echo ""
echo -e "  ${BOLD}Note:${NC} It may take a few minutes to connect to the network."
echo -e "  This is normal — keep the node running."
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -rp "$(echo -e "${CYAN}View live logs now? (y/N): ${NC}")" SHOWLOGS
if [[ "$SHOWLOGS" == "y" || "$SHOWLOGS" == "Y" ]]; then
  echo -e "${YELLOW}Press Ctrl+C to exit logs...${NC}\n"
  sleep 2
  docker compose logs -f cpu
fi
