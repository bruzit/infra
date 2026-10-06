# Infra

Infrastructure blueprints for workstations, home network, edge Kubernetes lab, and self-hosted services, provisioned with Ansible and Terraform under GitOps.

## Blueprints

| Blueprint       | Scope                                              | Status  |
|-----------------|----------------------------------------------------|---------|
| `PC`            | Workstations, laptops, gaming desktop, peripherals | Planned |
| `home-net`      | Routers, APs, switches, UPS, cabling               | Planned |
| `home-lab`      | Bare-metal servers, storage, Kubernetes            | Planned |
| `home-services` | Self-hosted services and their backups             | Planned |
| `home-web`      | Edge static hosting, CDN, domains                  | Planned |

## Hosts

| Group          | Hosts                          | Connection |
|----------------|--------------------------------|------------|
| `workstations` | `pc0`, `pc2`, `pc4`            | SSH        |
| `media`        | `pc3` (lab), `pc1` (household) | SSH        |
| `wsl`          | `wsl-beta`                     | Local      |

SSH hosts are reached by hostname. Bootstrap each one by running the playbook locally on it, which authorizes the keys from `github.com/bruzina.keys` and installs the SSH server:

```bash
ansible-playbook -K -c local -l <host> playbook.yaml
```

Afterwards run it from any controller holding a key listed on `github.com/bruzina.keys`. Ubuntu 25.10 and newer become via `sudo.ws` automatically.

## Provisioning

Fresh-system prerequisites and Ansible (`bruzit.ansible` requires ansible-core 2.20 or newer, which apt provides on Ubuntu 26.04 and newer; on 24.04 use `pipx install ansible` instead):

```bash
sudo apt install -y git ansible
```

Clone this repo (HTTPS, a fresh machine has no SSH key or GitHub CLI yet):

```bash
git clone https://github.com/bruzit/infra.git
cd infra
```

Add the machine to `inventory.yaml` under `workstations`, `media` or `wsl` if it is not there yet.

Install collections:

```bash
ansible-galaxy collection install -r requirements.yaml
```

Accounts are defined once in `group_vars/all/accounts.yaml` and passed to the `users`, `git`, `gh` and `docker` roles; each account's `repositories` are cloned into `~/Projects`.

Hosts are grouped in `inventory.yaml`: every host gets apt, users and git; `workstations` and `wsl` get claude, direnv, starship, gh, bitwarden_cli, terraform, docker, jq, pwgen and yq; `workstations` and `media` get ssh_server and fail2ban; `workstations` additionally get snap, obsidian, widelands and nerd_font (JetBrainsMono, system-wide Konsole default); `media` additionally get unattended_upgrades with automatic reboots and kodi; `wsl` hosts additionally get wsl (no systemd, snapd purged, Windows browser for `gh` and `xdg-open`; run `wsl --shutdown` from Windows after the first run), and the Docker daemon is started by hand with `sudo service docker start`. Always limit the run with `-l`; `-K` prompts for the sudo password:

```bash
ansible-playbook -K -l <inventory-hostname> playbook.yaml
```

Without a TTY, point Ansible at a password file instead (there is no environment variable for the password itself):

```bash
ANSIBLE_BECOME_PASSWORD_FILE=~/.ansible_become ansible-playbook -l <inventory-hostname> playbook.yaml
```

`wsl` hosts connect locally, so `ansible.builtin.reboot` refuses to run — keep `system_reboot_when_needed` false and reboot by hand after kernel upgrades.

## Cloud

`terraform/` creates the `test` environment in the Hetzner Cloud project "BruzIT Test": server `cloud0` (`cx23`, `hel1`, Ubuntu 26.04), a firewall allowing only SSH (22/tcp, key-only) and ICMP inbound, and an SSH key per key on `github.com/bruzina.keys`.
cloud-init creates user `mb` with those keys and passwordless sudo, and disables root and password login. State lives in the R2 bucket `bruzit-terraform-hetzner`, one Terraform workspace per environment. Addresses are private: outputs are sensitive and the workflow masks IP addresses.

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

In CI, run the manual `Terraform` workflow with `action` `apply` or `destroy`: job `Plan` plans read-only in the `test-plan` environment and writes the masked plan to the job summary; job `Apply` waits for approval of the `test` environment, then plans again and applies or destroys. Destroy promptly after testing, the server is billed hourly.

Test by `terraform -chdir=terraform init -backend=false && terraform -chdir=terraform test`, with mocked providers; pull requests run it in the `Terraform Test` workflow.

## Copyright and Licensing

[MIT License](LICENSE)  
Copyright © 2026 Martin Bružina