# Infra

Infrastructure blueprints for workstations, home network, edge Kubernetes lab, and self-hosted services, provisioned with Ansible and Terraform under GitOps.

## Blueprints

| Blueprint | Scope | Status |
|---|---|---|
| `PC` | Workstations, laptops, gaming desktop, peripherals | Planned |
| `home-net` | Routers, APs, switches, UPS, cabling | Planned |
| `home-lab` | Bare-metal servers, storage, Kubernetes | Planned |
| `home-services` | Self-hosted services and their backups | Planned |
| `home-web` | Edge static hosting, CDN, domains | Planned |

## Provisioning

Fresh-system prerequisites and Ansible (user-level via pipx; PEP 668 blocks system-wide pip installs):

```bash
sudo apt install -y git python3 python3-apt pipx
pipx install ansible
pipx ensurepath
```

Reopen the shell so the `pipx ensurepath` PATH change takes effect, then clone this repo:

```bash
git clone git@github.com:bruzit/infra.git
cd infra
```

Install collections (`bruzit.ansible` requires ansible-core 2.17 or newer):

```bash
ansible-galaxy collection install -r requirements.yaml
```

Hosts are grouped in `inventory.yaml`: every host gets apt, git, claude, gh and terraform; `workstations` additionally get snap, obsidian and widelands; `wsl` hosts get nothing more (no systemd, so no snap or flatpak). All hosts connect locally, so always limit the run to the current machine with `-l`; `-K` prompts for the sudo password:

```bash
ansible-playbook -K -l <inventory-hostname> playbook.yaml
```

Without a TTY, point Ansible at a password file instead (there is no environment variable for the password itself):

```bash
ANSIBLE_BECOME_PASSWORD_FILE=~/.ansible_become ansible-playbook -l <inventory-hostname> playbook.yaml
```

`inventory.yaml` connects locally, so `ansible.builtin.reboot` refuses to run — keep `reboot_when_needed` false and reboot by hand after kernel upgrades.

## Copyright and Licensing

[MIT License](LICENSE)  
Copyright © 2026 Martin Bružina