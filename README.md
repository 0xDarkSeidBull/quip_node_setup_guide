# Quip Network : CPU Node Setup Guide (Ubuntu VPS)
<img width="1919" height="779" alt="image" src="https://github.com/user-attachments/assets/839fcc44-1686-443c-a836-4e20900ac099" />

> **Deadline:** Get your node running before **April 15, 2026** to qualify for the initial quest drop.

---

## Requirements

- Ubuntu 22.04 VPS (minimum 2 CPU, 4GB RAM, 20GB SSD)
- Docker + Docker Compose installed
- Open ports: `20049/udp` and `20049/tcp`
- A GitLab account with access to the [nodes.quip.network](https://gitlab.com/quip.network/nodes.quip.network) repo
- An EVM wallet address (MetaMask / Rabby)

---

## Step 1 — Install Docker

```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | bash
sudo systemctl enable docker && sudo systemctl start docker
sudo apt install docker-compose-plugin -y
```

Verify:

```bash
docker --version
docker compose version
```

---

## Step 2 — Open Ports

```bash
ufw allow 20049/udp
ufw allow 20049/tcp
```

---

## Step 3 — Clone the Repo

You need a GitLab Personal Access Token with `read_repository` scope.
Generate one at: https://gitlab.com/-/profile/personal_access_tokens

```bash
git clone https://YOUR_GITLAB_USERNAME:YOUR_TOKEN@gitlab.com/quip.network/nodes.quip.network.git
cd nodes.quip.network
```

---

## Step 4 — Configure the Node

```bash
cp data/config.cpu.toml data/config.toml
nano data/config.toml
```

Set these values:

Generate your secret first:

```bash
openssl rand -hex 32
```

Paste the output as your `secret` value:

```toml
secret = "your_generated_hex_string_here"
public_host = "YOUR_VPS_PUBLIC_IP"
node_name = "YourHandle - 0xYourWalletAddress"
auto_mine = true
tofu = true
```

**Node name format is important** — use `Handle - 0xWallet` (space-dash-space) exactly as shown. This is how Quip maps your node to your wallet for rewards.

Example:
```toml
node_name = "0xDarkSeidBull - 0x3bc6348e1e569e97bd8247b093475a4ac22b9fd4"
```

> **Which wallet to use?** Use the same EVM wallet address you connected on:
> - Quest dashboard: [https://quest.quip.network/airdrop](https://quest.quip.network/airdrop?referral_code=DARKSEID) 
> ## Bonus — Genesis Block Inscription
Leave your mark on the Quip Network genesis block:
> - Quip account: [https://account.quip.network](https://account.quip.network/?ref=0x3bc6348e1e569e97bd8247b093475a4ac22b9fd4)
> On the account page, your connected address shows under **Your Accounts**. Use that exact address in your `node_name`. Keeping the same wallet across node, quest site, and account page ensures rewards are mapped correctly.

---

## Step 5 — Configure Environment

```bash
cp env.example .env
nano .env
```

If you're using an IP address (not a domain), leave `CERT_EMAIL` blank.

If port 80 or 443 is already in use on your VPS (e.g. nginx running), comment them out in `docker-compose.yml`:

```yaml
# - "80:80"
# - "443:443"
```

---

## Step 6 — Start the Node

```bash
docker compose --profile cpu up -d
```

Check logs:

```bash
docker compose logs -f cpu
```

**Healthy output looks like:**

```
Miner built successfully: CPU
Network node started at quic://:::20049
QUIC connection established to nodes.quip.network:20049
[Block-N] Mined! Nonce: ...
```

---

## Step 7 — Enable Auto-Updates

Install an hourly cron job that pulls the latest image automatically:

```bash
chmod +x cron.sh
./cron.sh --install
```

This ensures your node stays on the latest version without manual intervention.

---

## Maintenance Commands

| Task | Command |
|------|---------|
| View logs | `docker compose logs -f cpu` |
| Restart after config change | `docker compose restart cpu` |
| Force update image | `docker compose pull cpu && docker compose up -d cpu` |
| Stop node | `docker compose --profile cpu down` |
| View auto-update logs | `tail -f data/update.log` |

---

## Common Issues

**`public_host must be a hostname or IP without a port`**
→ Use only the IP, no port: `public_host = "1.2.3.4"` not `"1.2.3.4:20049"`

**`port already in use` (80 or 443)**
→ Comment out those port lines in `docker-compose.yml` (see Step 5)

**`Local version X.X.X is outdated`**
→ Run `./cron.sh` to force-pull the latest image, then restart

**`No peers connected, automining`**
→ Normal during network congestion. Node is still mining and contributing. Keep it running.

**GitLab clone returns 404**
→ Use `quip.network` (dot) not `quip-network` (dash) in the URL

---

## Multiple Nodes (Same Wallet)

You can run nodes on multiple VPS machines pointing to the same wallet:

```toml
node_name = "YourHandle-1 - 0xYourWalletAddress"
node_name = "YourHandle-2 - 0xYourWalletAddress"
```

---

## Resources

- [Official Repo](https://gitlab.com/quip.network/nodes.quip.network)
- [Quip Network Discord](https://discord.gg/quipnetwork)
- [Quest Dashboard](https://quest.quip.network)
- [Telemetry Dashboard](https://quip-dashboard.netlify.app)

---

*Guide by [@cryptobhartiyax](https://twitter.com/cryptobhartiyax)*
