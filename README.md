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

## Copyright and Licensing

[MIT License](LICENSE)  
Copyright © 2026 Martin Bružina