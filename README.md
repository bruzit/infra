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

Fresh-system prerequisites and Ansible (`bruzit.ansible` requires ansible-core 2.20 or newer, which apt provides on Ubuntu 26.04 and newer; on 24.04 use `pipx install ansible` instead):

```bash
sudo apt install -y git ansible
```

Clone this repo (HTTPS, a fresh machine has no SSH key or GitHub CLI yet):

```bash
git clone https://github.com/bruzit/infra.git
cd infra
```

Add the machine to `inventory.yaml` under `workstations` or `wsl` if it is not there yet.

Install collections:

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