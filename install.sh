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

step() {
  echo -e "\n${GREEN}[+]${NC} ${BOLD}$1${NC}"
}

warn() {
  echo -e "${YELLOW}[!]${NC} $1"
}

error() {
  echo -e "${RED}[✗]${NC} $1"
  exit 1
}

ok() {
  echo -e "${GREEN}[✓]${NC} $1"
}

# ── 0. Banner ──────────────────────────────────────────────
clear
banner

echo -e "${BOLD}Yeh script automatically setup karega:${NC}"
echo "  • Docker install (if missing)"
echo "  • Ports open (20049 UDP/TCP)"
echo "  • Quip repo clone"
echo "  • Config auto-generate"
echo "  • Node start"
echo "  • Auto-update cron"
echo ""
echo -e "${YELLOW}Press ENTER to continue or Ctrl+C to cancel...${NC}"
read -r

# ── 1. Collect user input ──────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Step 1: Your Details${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -rp "$(echo -e "${CYAN}Enter your handle${NC} (e.g. 0xDarkSeidBull): ")" HANDLE
[[ -z "$HANDLE" ]] && error "Handle cannot be empty."

read -rp "$(echo -e "${CYAN}Enter your EVM wallet address${NC} (0x...): ")" WALLET
[[ "$WALLET" != 0x* ]] && error "Wallet must start with 0x"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  GitLab Token Required — Yeh steps follow karo:${NC}"
echo ""
echo -e "  1. Yahan jao (browser mein open karo):"
echo -e "     ${CYAN}https://gitlab.com/-/profile/personal_access_tokens${NC}"
echo ""
echo -e "  2. Token name: ${YELLOW}quip-node${NC} (kuch bhi)"
echo -e "  3. Expiration: blank chhod do"
echo -e "  4. Scope: sirf ${YELLOW}read_repository${NC} check karo"
echo -e "  5. 'Create personal access token' click karo"
echo -e "  6. Token copy karo (ek baar hi dikhega!)"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "$(echo -e "${CYAN}Token ready hai? ENTER dabao phir paste karo...${NC}")" 
echo ""
read -rp "$(echo -e "${CYAN}GitLab Token paste karo: ${NC}")" GITLAB_TOKEN
[[ -z "$GITLAB_TOKEN" ]] && error "GitLab token cannot be empty."

read -rp "$(echo -e "${CYAN}Enter your VPS public IP${NC}: ")" PUBLIC_IP
[[ -z "$PUBLIC_IP" ]] && error "IP cannot be empty."

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Node Name will be: ${YELLOW}${HANDLE} - ${WALLET}${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -rp "$(echo -e "${CYAN}Sab theek hai? Continue? (y/N): ${NC}")" CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && error "Aborted."

# ── 2. Docker install ──────────────────────────────────────
step "Docker check kar raha hoon..."
if ! command -v docker &> /dev/null; then
  warn "Docker nahi mila — install kar raha hoon..."
  apt-get update -qq
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker && systemctl start docker
  apt-get install -y -qq docker-compose-plugin
  ok "Docker install ho gaya"
else
  ok "Docker already installed: $(docker --version)"
fi

if ! docker compose version &> /dev/null; then
  warn "docker-compose-plugin install kar raha hoon..."
  apt-get install -y -qq docker-compose-plugin
fi
ok "Docker Compose ready"

# ── 3. Open ports ──────────────────────────────────────────
step "Ports open kar raha hoon (20049 UDP/TCP)..."
if command -v ufw &> /dev/null; then
  ufw allow 20049/udp > /dev/null 2>&1 || true
  ufw allow 20049/tcp > /dev/null 2>&1 || true
  ok "UFW ports open"
else
  warn "UFW nahi mila — manually check karo ki 20049 open hai"
fi

# ── 4. Clone repo ──────────────────────────────────────────
step "Quip repo clone kar raha hoon..."
INSTALL_DIR="$HOME/nodes.quip.network"

if [[ -d "$INSTALL_DIR" ]]; then
  warn "Directory already exists: $INSTALL_DIR"
  read -rp "$(echo -e "${YELLOW}Delete karke fresh clone karein? (y/N): ${NC}")" RECLONE
  if [[ "$RECLONE" == "y" || "$RECLONE" == "Y" ]]; then
    rm -rf "$INSTALL_DIR"
  else
    warn "Existing directory use kar raha hoon..."
  fi
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  git clone "https://oauth2:${GITLAB_TOKEN}@gitlab.com/quip.network/nodes.quip.network.git" "$INSTALL_DIR" \
    || error "Clone failed — GitLab token ya URL check karo"
  ok "Repo cloned: $INSTALL_DIR"
else
  ok "Existing repo use kar raha hoon"
fi

cd "$INSTALL_DIR"

# ── 5. Generate config ─────────────────────────────────────
step "Config generate kar raha hoon..."
SECRET=$(openssl rand -hex 32)

cp data/config.cpu.toml data/config.toml

# Replace values using sed
sed -i "s|secret = .*|secret = \"${SECRET}\"|" data/config.toml
sed -i "s|public_host = .*|public_host = \"${PUBLIC_IP}\"|" data/config.toml
sed -i "s|node_name = .*|node_name = \"${HANDLE} - ${WALLET}\"|" data/config.toml
sed -i "s|auto_mine = .*|auto_mine = true|" data/config.toml
sed -i "s|tofu = .*|tofu = true|" data/config.toml

ok "config.toml ready"

# ── 6. Setup .env ──────────────────────────────────────────
step ".env setup kar raha hoon..."
if [[ -f "env.example" ]]; then
  cp env.example .env
  # Blank out CERT_EMAIL if using IP
  sed -i "s|CERT_EMAIL=.*|CERT_EMAIL=|" .env
  ok ".env ready"
else
  touch .env
  warn "env.example nahi mila — empty .env banaya"
fi

# ── 7. Handle port conflicts ───────────────────────────────
step "Port conflicts check kar raha hoon (80/443)..."
PORT80=$(ss -tlnp 2>/dev/null | grep ':80 ' || true)
PORT443=$(ss -tlnp 2>/dev/null | grep ':443 ' || true)

if [[ -n "$PORT80" || -n "$PORT443" ]]; then
  warn "Port 80/443 already in use — docker-compose.yml se comment out kar raha hoon..."
  sed -i 's|^\s*- "80:80"|      # - "80:80"|' docker-compose.yml
  sed -i 's|^\s*- "443:443"|      # - "443:443"|' docker-compose.yml
  ok "Port conflict fix ho gaya"
else
  ok "Ports 80/443 free hain"
fi

# ── 8. Start node ──────────────────────────────────────────
step "Node start kar raha hoon..."
docker compose --profile cpu pull -q
docker compose --profile cpu up -d
ok "Node started!"

# ── 9. Auto-update cron ────────────────────────────────────
step "Auto-update cron install kar raha hoon..."
if [[ -f "cron.sh" ]]; then
  chmod +x cron.sh
  ./cron.sh --install
  ok "Auto-update cron active"
else
  warn "cron.sh nahi mila — manually setup karo"
fi

# ── 10. Done ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅  NODE LIVE HO GAYA!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Node Name:${NC}  ${YELLOW}${HANDLE} - ${WALLET}${NC}"
echo -e "  ${BOLD}Public IP:${NC}  ${YELLOW}${PUBLIC_IP}${NC}"
echo -e "  ${BOLD}Directory:${NC}  ${YELLOW}${INSTALL_DIR}${NC}"
echo ""
echo -e "  ${BOLD}Logs dekhne ke liye:${NC}"
echo -e "  ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f cpu${NC}"
echo ""
echo -e "  ${BOLD}Network stats:${NC} ${CYAN}https://republicstats.xyz${NC}"
echo -e "  ${BOLD}Quest dashboard:${NC} ${CYAN}https://quest.quip.network/airdrop${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show live logs
read -rp "$(echo -e "${CYAN}Live logs dekhna chahte ho? (y/N): ${NC}")" SHOWLOGS
if [[ "$SHOWLOGS" == "y" || "$SHOWLOGS" == "Y" ]]; then
  echo -e "${YELLOW}Ctrl+C se exit karo logs se...${NC}\n"
  sleep 2
  docker compose logs -f cpu
fi
