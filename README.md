# BruzIT Infra

[![License](https://img.shields.io/github/license/bruzit/infra)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/bruzit/infra)](https://github.com/bruzit/infra/commits)
[![MegaLinter](https://github.com/bruzit/infra/actions/workflows/megalinter.yaml/badge.svg)](https://github.com/bruzit/infra/actions/workflows/megalinter.yaml)
[![Terraform Test](https://github.com/bruzit/infra/actions/workflows/terraform-test.yaml/badge.svg)](https://github.com/bruzit/infra/actions/workflows/terraform-test.yaml)
[![Semantic Release](https://github.com/bruzit/infra/actions/workflows/semantic-release.yaml/badge.svg)](https://github.com/bruzit/infra/actions/workflows/semantic-release.yaml)
[![Terraform](https://github.com/bruzit/infra/actions/workflows/terraform.yaml/badge.svg)](https://github.com/bruzit/infra/actions/workflows/terraform.yaml)

Infrastructure blueprints for workstations, home network, edge Kubernetes lab, and self-hosted services, provisioned with Ansible and Terraform under GitOps.

## Features

| Blueprint       | Scope                                              | Status      | Provisioned                                               |
|-----------------|----------------------------------------------------|-------------|-----------------------------------------------------------|
| `PC`            | Workstations, laptops, gaming desktop, peripherals | In progress | `workstations`, `wsl`; peripherals not yet                |
| `home-net`      | Routers, APs, switches, UPS, cabling               | Planned     | None                                                      |
| `home-lab`      | Bare-metal servers, storage, Kubernetes            | Planned     | None; `appliances` inventory only                         |
| `home-services` | Self-hosted services and their backups             | In progress | `media` (Kodi); backups not yet                           |
| `home-web`      | Edge static hosting, CDN, domains                  | In progress | `cloud` test server (Terraform, Hetzner); hosting not yet |

Status: Provisioned (whole scope converged by `playbook.yaml` or Terraform), In progress (part of the scope), Planned (not started).

## Requirements

- Ubuntu 24.04 or newer; `appliances` (Synology DSM) are inventory only.
- ansible-core 2.20 or newer (required by [BruzIT Ansible Collection](https://github.com/bruzit/ansible-collection)), collections in [`requirements.yaml`](requirements.yaml).
- Cloud: Terraform 1.15 or newer 1.x, direnv, a Hetzner Cloud project and a Cloudflare R2 bucket for state.

## Installation and Setup

### Hosts

| Group          | Hosts                             | Connection          |
|----------------|-----------------------------------|---------------------|
| `workstations` | `pc0`, `pc2`, `pc4`               | SSH                 |
| `media`        | `pc3` (lab), `pc1` (household)    | SSH                 |
| `wsl`          | `wsl-beta`                        | Local               |
| `cloud`        | `cloud0` (Hetzner, `hcloud.yaml`) | SSH                 |
| `appliances`   | `nas0`, `nas1`                    | None (Synology DSM) |

Tier groups set `bruzit_tier`: `test` (`pc0`, `pc3`, `cloud0`), `prod` (the rest); the playbook fails hosts without a valid tier.

### Bootstrap

On a fresh system (apt provides ansible-core 2.20 from Ubuntu 26.04; on 24.04 use `pipx install ansible`), clone over HTTPS into `~/Projects`, where the `git` role skips existing clones:

```bash
sudo apt install -y git ansible
git clone https://github.com/bruzit/infra.git ~/Projects/infra
cd ~/Projects/infra
ansible-galaxy collection install -r requirements.yaml
```

Add the host to [`inventory.yaml`](inventory.yaml) under `workstations`, `media` or `wsl`, then run the playbook locally; it authorizes the keys from `github.com/bruzina.keys` and installs the SSH server:

```bash
ansible-playbook -K -c local -l <host> playbook.yaml
```

Afterwards run it from any controller. SSH hosts are reached by hostname; Ubuntu 25.10 and newer become via `sudo.ws` automatically.

### Controller

Every `workstations` and `wsl` host is a controller: the first local run installs gh (git credential helper) and direnv and generates the SSH key `~/.ssh/id_ed25519` and the commit signing key `~/.ssh/id_ed25519_signing`. Log in to GitHub and register both keys (if already logged in, `gh auth refresh -s admin:ssh_signing_key` first):

```bash
gh auth login -h github.com -p https -w -s admin:public_key,admin:ssh_signing_key
gh ssh-key add ~/.ssh/id_ed25519.pub -t <host>
gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing -t <host>
```

Copy the `.env*` files and GitHub App PEMs from an existing controller into the matching checkouts under `~/Projects`, then run `direnv allow` in each. From an existing controller, re-run the playbook on the other SSH hosts so their authorized keys include the new key, then verify:

```bash
ansible-playbook -K -l <host> playbook.yaml
ansible -m ping workstations:media
```

## Usage

### Provision Hosts

Accounts are defined once in [`group_vars/all/accounts.yaml`](group_vars/all/accounts.yaml); each account's `repositories` are cloned into `~/Projects`. Roles per group, from [`playbook.yaml`](playbook.yaml):

| Group                            | Roles                                                                                                                                  |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| All but `appliances`             | apt, users                                                                                                                             |
| `workstations`, `wsl`            | SSH key, git (identity, SSH commit signing, clones), claude, direnv, starship, gh, bitwarden_cli, terraform, docker, jq, pwgen, yq, mc |
| `workstations`, `media`, `cloud` | ssh_server, fail2ban                                                                                                                   |
| `workstations`                   | snap, obsidian, widelands, nerd_font, vscode, vscodium, google_chrome, openttd; unattended_upgrades without reboot                     |
| `media`, `cloud`                 | unattended_upgrades with automatic reboot                                                                                              |
| `media`                          | kodi_youtube, kodi_netflix: Kodi with YouTube, Netflix and InputStream Adaptive add-ons, web remote control, Avahi discovery           |
| `wsl`                            | wsl: no systemd, snapd purged, Windows browser for `gh` and `xdg-open`; no nftables firewall                                           |

Always limit the run with `-l`; `-K` prompts for the sudo password, without a TTY use a password file:

```bash
ansible-playbook -K -l <host> playbook.yaml
ANSIBLE_BECOME_PASSWORD_FILE=~/.ansible_become ansible-playbook -l <host> playbook.yaml
```

Host notes:

- `media`: Kodi web server password from `KODI_WEBSERVER_PASSWORD` in `.env`; `pc1` outputs to its `HDMI-A-1` TV with HDMI audio.
- `wsl`: run `wsl --shutdown` from Windows after the first run; start Docker by hand with `sudo service docker start`; `ansible.builtin.reboot` refuses local connections, so keep `system_reboot_when_needed` false and reboot by hand after kernel upgrades. `wsl-beta` resolves DNS via the WSL NAT gateway.

### Cloud

[`terraform/`](terraform) creates the `test` environment in the Hetzner Cloud project "BruzIT Test": server `cloud0` (`cx23`, `hel1`, Ubuntu 26.04), a firewall allowing only SSH (22/tcp, key-only) and ICMP inbound, and an SSH key per key on `github.com/bruzina.keys`.
cloud-init creates user `mb` with those keys and passwordless sudo, and disables root and password login. State lives in the R2 bucket `$AWS_BUCKET`, one Terraform workspace per environment. Addresses are private: outputs are sensitive and the workflow masks IP addresses.

Credentials come from direnv: `.env` (shared, from `.env.tmpl`) and `.env.<env>.<mode>` (from `.env.test.<mode>.tmpl`), selected by `TF_ENV` (default `test`) and `TF_MODE` (`plan`, the default, with read-only tokens, or `apply` with read-write tokens).

Bootstrap the workspace once, since the read-only R2 token cannot create it:

```bash
TF_MODE=apply direnv exec . terraform -chdir=terraform init -backend-config="bucket=$AWS_BUCKET"
```

Plan, apply and destroy locally:

```bash
terraform -chdir=terraform init -backend-config="bucket=$AWS_BUCKET"
terraform -chdir=terraform plan -lock=false
TF_MODE=apply direnv exec . terraform -chdir=terraform apply
TF_MODE=apply direnv exec . terraform -chdir=terraform destroy
```

SSH in by `ssh mb@"$(terraform -chdir=terraform output -raw ipv4_address)"`.

Servers labeled `role=cloud` form the inventory group `cloud`, and their `env` label (the Terraform workspace, i.e. the tier) the tier group and `bruzit_tier`, discovered by the [hetzner.hcloud: hcloud inventory plugin documentation](https://docs.ansible.com/ansible/latest/collections/hetzner/hcloud/hcloud_inventory.html) via [`hcloud.yaml`](hcloud.yaml) with `HCLOUD_TOKEN` and reached by public IPv4 as `mb` (passwordless sudo, no `-K`). `hcloud.yaml` is not in `ansible.cfg` since it fails without a token, so pass both inventories. `TF_ENV` picks the token and thus the Hetzner project, while `-l 'cloud:&<env>'` guards against a mismatched `TF_ENV`, which then selects no hosts. Converge the test environment: run the `Terraform` workflow with `apply` and approve it, then:

```bash
TF_ENV=test direnv exec . ansible-playbook -i inventory.yaml -i hcloud.yaml -l 'cloud:&test' playbook.yaml
```

Then run the workflow with `destroy`. Unknown host keys are accepted on first contact; a recycled address with a changed key needs `ssh-keygen -R <address>`.

## Support

Demo: a reference implementation of BruzIT products in use, best effort; [open a GitHub issue](../../issues).

## Testing

MegaLinter (Ansible, Terraform, YAML, Markdown, GitHub Actions) and Terraform `fmt`, `validate` and `test` with mocked providers run on pull requests. Locally:

```bash
terraform -chdir=terraform init -backend=false && terraform -chdir=terraform test
```

## Integration and Deployment

| Workflow                                                            | Trigger                          | Purpose                                                                                   |
|---------------------------------------------------------------------|----------------------------------|-------------------------------------------------------------------------------------------|
| [MegaLinter](.github/workflows/megalinter.yaml)                     | Pull request                     | Lint changed files; required check `Required (MegaLinter)`                                |
| [Terraform Test](.github/workflows/terraform-test.yaml)             | Pull request                     | Terraform `fmt`, `validate`, `test`; required check `Required (Terraform Test)`           |
| [MegaLinter Scheduled](.github/workflows/megalinter-scheduled.yaml) | Weekly, Monday 06:00 UTC; manual | Lint the whole codebase                                                                   |
| [Semantic Release](.github/workflows/semantic-release.yaml)         | Push to `main`                   | Version, changelog and GitHub release                                                     |
| [Terraform](.github/workflows/terraform.yaml)                       | Manual, `apply` or `destroy`     | `Plan` read-only in environment `test-plan`; `Apply` after approval of environment `test` |

The `Terraform` workflow writes the IP-masked plan to the job summary; `Apply` plans again before applying or destroying. Destroy promptly after testing, the server is billed hourly.

## Contributing

Open a pull request to `main`. Commits follow the [Conventional Commits 1.0.0 specification](https://www.conventionalcommits.org/en/v1.0.0/), from which semantic-release sets versions and the changelog automatically.

## License and Copyright

MIT License: [`LICENSE`](LICENSE)  
Copyright © 2026 Martin Bružina

## References

- [BruzIT Ansible Collection](https://github.com/bruzit/ansible-collection)
- [BruzIT GitHub Actions and Workflows](https://github.com/bruzit/github-actions-and-workflows)
- [hetznercloud/hcloud: Terraform provider documentation](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)

## Stats

| Metric           | Badges                                                                                                                                                                                                                                                                                                                                                                                                                     |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Commits          | [![Commits total](https://img.shields.io/github/commit-activity/t/bruzit/infra?label=commits%20total)](https://github.com/bruzit/infra/commits/main)                                                                                                                                                                                                                                                                       |
| Issues           | [![Issues open](https://img.shields.io/github/issues/bruzit/infra?label=issues)](https://github.com/bruzit/infra/issues) [![Issues total](https://img.shields.io/github/issues-search?query=repo%3Abruzit%2Finfra%20is%3Aissue&label=issues%20total)](https://github.com/bruzit/infra/issues?q=is%3Aissue)                                                                                                                 |
| Pull requests    | [![Pull requests open, not draft](https://img.shields.io/github/issues-search?query=repo%3Abruzit%2Finfra%20is%3Apr%20is%3Aopen%20draft%3Afalse&label=PRs%20open)](https://github.com/bruzit/infra/pulls?q=is%3Apr+is%3Aopen+draft%3Afalse) [![Pull requests total](https://img.shields.io/github/issues-search?query=repo%3Abruzit%2Finfra%20is%3Apr&label=PRs%20total)](https://github.com/bruzit/infra/pulls?q=is%3Apr) |
| Checks on `main` | [![Checks on main](https://img.shields.io/github/check-runs/bruzit/infra/main?label=checks%20%28main%29)](https://github.com/bruzit/infra/actions?query=branch%3Amain)                                                                                                                                                                                                                                                     |
| Releases         | [![Latest release](https://img.shields.io/github/v/release/bruzit/infra)](https://github.com/bruzit/infra/releases/latest) [![Commits since latest release](https://img.shields.io/github/commits-since/bruzit/infra/latest)](https://github.com/bruzit/infra/releases)                                                                                                                                                    |
| Community        | [![Stargazers](https://img.shields.io/github/stars/bruzit/infra)](https://github.com/bruzit/infra/stargazers) [![Forks](https://img.shields.io/github/forks/bruzit/infra)](https://github.com/bruzit/infra/forks) [![Contributors](https://img.shields.io/github/contributors/bruzit/infra)](https://github.com/bruzit/infra/graphs/contributors)                                                                          |
