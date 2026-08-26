# Quip Network : CPU Node Setup Guide (Ubuntu VPS)
<img width="1919" height="779" alt="image" src="https://github.com/user-attachments/assets/839fcc44-1686-443c-a836-4e20900ac099" />

# Quip Network: CPU Node Setup Guide (Ubuntu VPS)

Updated for the **v0.3 coordinator** rollout (Rust `quip-coordinator`, replacing the old
Python-only miner flow). If you set a node up before ~August 2026, re-read Steps 4–6 
the config schema and image paths both changed.

---

## Requirements

- Ubuntu 22.04 VPS (minimum 2 CPU, 4GB RAM, 20GB SSD)
- Docker + Docker Compose installed
- Open ports: `20049/udp` and `20049/tcp`
- A GitLab account with access to the [nodes.quip.network](https://gitlab.com/quip.network/nodes.quip.network) repo
- A GitLab **Personal Access Token with both `read_repository` AND `read_registry` scopes**
  (the repo clone only needs `read_repository`; pulling the miner/validator container
  images needs `read_registry` too  a token with only the first scope will clone fine
  but every `docker compose pull` will fail with `access forbidden` / `pull access denied`)
- An EVM wallet address (MetaMask / Rabby)
- Your VPS's public IP address (`curl -4 ifconfig.me`)

---

## Step 1: Install Docker

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

## Step 2: Open Ports

```bash
ufw allow 20049/udp
ufw allow 20049/tcp
```

---

## Step 3: Clone the Repo

Generate a token at `https://gitlab.com/-/user_settings/personal_access_tokens`
with `read_repository` **and** `read_registry` checked.

```bash
git clone https://YOUR_GITLAB_USERNAME:YOUR_TOKEN@gitlab.com/quip.network/nodes.quip.network.git
cd nodes.quip.network
```

Also log Docker itself into the registry  `docker compose pull` needs this
independently of the git clone:

```bash
docker login registry.gitlab.com -u YOUR_GITLAB_USERNAME
# paste your token (not your GitLab password) at the prompt
```

---

## Step 4: Configure the Node

```bash
cp data/config.cpu.toml data/config.toml
```

Generate your secret:

```bash
openssl rand -hex 32
```

Edit `data/config.toml`. The current schema nests everything under **`[miner]`** 
older guides/screenshots showing top-level keys are stale:

```toml
[miner]
secret = "your_generated_hex_string_here"
public_host = "YOUR_VPS_PUBLIC_IP"
public_port = 8086
node_name = "YourHandle - 0xYourWalletAddress"
validators = [
    "ws://quip-validator:9944",
]
signer_key = "/data/keystore.json"
faucet_url = "https://faucet.testnet.quip.network"
rest_port = 8086
rest_host = "0.0.0.0"
log_level = "INFO"
node_log = "/data/logs/quip-node.log"

[cpu]
```

> **`public_host` and `public_port` are documented as optional / auto-detected, but
> the `quip-coordinator` binary currently hard-requires both**  omit either one and
> the container crash-loops with `error=missing [miner].public_host` (or `.public_port`).
> Set `public_port` to the same value as `rest_port` (8086 by default) unless you've
> deliberately split them.

**Node name format matters**: `Handle - 0xWallet` (space-dash-space), exactly as shown.
This is how Quip maps your node to your wallet for rewards.

Example:
```toml
node_name = "0xDarkSeidBull - 0x3bc6348e1e569e97bd8247b093475a4ac22b9fd4"
```

> **Which wallet to use?** Use the same EVM wallet address you connected on:
> - Quest dashboard: [https://quest.quip.network/airdrop](https://quest.quip.network/airdrop?referral_code=DARKSEID)
>
> ## Bonus: Genesis Block Inscription
> Leave your mark on the Quip Network genesis block:
> - Quip account: [https://account.quip.network](https://account.quip.network/?ref=0x3bc6348e1e569e97bd8247b093475a4ac22b9fd4)
>
> On the account page, your connected address shows under **Your Accounts**. Use that
> exact address in your `node_name`. Keeping the same wallet across node, quest site,
> and account page ensures rewards are mapped correctly.

---

## Step 5: Configure Environment

```bash
cp env.example .env
nano .env
```

If you're using an IP address (not a domain), leave `CERT_EMAIL` blank.

**Do not pin `QUIP_MINER_TAG` to an old version** (e.g. `v0.2`). The miner image path
has moved at least twice as the project renamed GitLab groups
(`quip-protocol/quip-miner-cpu` → `quip-miner/v0.3/quip-miner`), and old tags routinely
stop resolving after a rename. Either delete the `QUIP_MINER_TAG` line entirely (the
compose file's own default tracks `latest`) or set it explicitly:

```bash
QUIP_MINER_TAG=latest
```

If port 80 or 443 is already in use on your VPS (e.g. Caddy/Nginx already running,
or another site sharing the box), comment them out in `docker-compose.yml`:

```yaml
# - "80:80"
# - "443:443"
```

---

## Step 6: Start the Node

Pull explicitly before starting  `docker compose up -d` alone will silently keep
running whatever image is already cached locally if the pull fails, which hides
version-mismatch problems:

```bash
docker compose pull cpu && docker compose up -d cpu
```

Check logs:

```bash
docker compose logs -f cpu
```

**Healthy output looks like:**

```
quip_coordinator: quip-coordinator starting version="0.3.x" protocol=1
quip_coordinator::chain::real: validator RPC reachable url=ws://quip-validator:9944
quip_coordinator::chain::preflight: validator runtime spec_name=quip spec_version=...
quip_coordinator::readiness: filed node descriptor
quip_coordinator::supervisor: miner spawned miner=cpu-0 binary=quip-cpu-sa
quip_coordinator::runtime: new round generation=1 ...
quip_solver_core::session: [quip-miner-cpu] attempt ...: energy ..., valid .../...
```

If instead you see `exited with code 64` repeating with `invalid config ... error=missing
[miner].<field>`, that field needs adding to `data/config.toml`  see Step 4 and the
Common Issues table below.

---

## Step 7: Enable Auto-Updates

Install an hourly cron job that pulls the latest image automatically:

```bash
chmod +x cron.sh
./cron.sh --install
```

This ensures your node stays on the latest version without manual intervention.
Because of the `QUIP_MINER_TAG` gotcha above, confirm your `.env` doesn't have a
stale pinned tag before relying on this  a pinned old tag will make auto-update a
no-op (or start failing outright once that tag stops resolving).

---

## Maintenance Commands

| Task | Command |
|------|---------|
| View logs | `docker compose logs -f cpu` |
| Tail logs without blocking your shell | `nohup docker compose logs -f cpu > /root/quip-cpu-watch.log 2>&1 & disown` then `tail -f /root/quip-cpu-watch.log` |
| Restart after config change | `docker compose restart cpu` |
| Force update image | `docker compose pull cpu && docker compose up -d cpu` |
| Confirm which image tag is actually running | `docker compose images cpu` |
| Stop node | `docker compose --profile cpu down` |
| View auto-update logs | `tail -f data/update.log` |
| Check registry login is still valid | `docker pull registry.gitlab.com/quip.network/quip-miner/v0.3/quip-miner:latest` |

---

## Common Issues

**`public_host must be a hostname or IP without a port`**
→ Use only the IP, no port: `public_host = "1.2.3.4"` not `"1.2.3.4:20049"`

**`error=missing [miner].public_host` or `error=missing [miner].public_port`**
→ Both are required by the current `quip-coordinator` despite being documented as
optional/auto-detected. Add them explicitly under `[miner]`  see Step 4.

**`port already in use` (80 or 443)**
→ Comment out those port lines in `docker-compose.yml` (see Step 5). Check what's
actually bound first with `ss -tlnp | grep -E ':80 |:443 '`  on boxes with an
existing reverse proxy (Caddy, Nginx) this is expected and safe to just comment out.

**`docker compose pull` → `access forbidden`**
→ You're not logged into the registry, or your token lacks `read_registry` scope.
Run `docker login registry.gitlab.com` with a token that has both scopes (Step 3).

**`docker compose pull` → `pull access denied` / `not found` even after logging in**
→ The image path itself may have moved (GitLab project rename). Check the current
`image:` line in `docker-compose.yml` against what actually resolves  try
`docker pull <image>:latest` directly to confirm the path/tag exists before assuming
your config is wrong.

**Node keeps running an old image despite `docker compose up -d`**
→ `up -d` alone reuses the cached local image if the pull step fails or is skipped.
Always run `docker compose pull cpu && docker compose up -d cpu` together, and
confirm with `docker compose images cpu` afterward.

**`Local version X.X.X is outdated`**
→ Run `./cron.sh` to force-pull the latest image, then restart. If `.env` pins
`QUIP_MINER_TAG` to an old version, this will not help  remove the pin first.

**`No peers connected, automining`**
→ Normal during network congestion. Node is still mining and contributing. Keep it running.

**GitLab clone returns 404**
→ Use `quip.network` (dot) not `quip-network` (dash) in the URL.

**Wallet/faucet errors that look like a Python traceback (`ValueError`, "Enum type
mapping", etc.)**
→ Usually a transient client/chain version-skew during active development, not a
config problem. Confirm you're on `QUIP_MINER_TAG=latest` (not a pinned old tag) and
check the [quip-miner](https://github.com/QuipNetwork/quip-miner) repo's recent
commits/issues  these tend to get patched within days.

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
- [quip-miner source](https://github.com/QuipNetwork/quip-miner)
- [Quip Network Discord](https://discord.gg/quipnetwork)
- [Quest Dashboard](https://quest.quip.network)
- [Telemetry Dashboard](https://quip-dashboard.netlify.app)

---

*Guide by [@cryptobhartiyax](https://twitter.com/cryptobhartiyax)  updated after a
live v0.2→v0.3 migration debugging session, August 2026.*


