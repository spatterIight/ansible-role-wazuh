<!--
SPDX-FileCopyrightText: 2025 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Wazuh Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Wazuh](https://wazuh.com) to run as [Docker](https://www.docker.com/) containers wrapped in systemd services.

The role deploys the full Wazuh single-node topology:

- **Wazuh Manager** — SIEM engine, agent enrollment, rules engine, Filebeat forwarder
- **Wazuh Indexer** — OpenSearch-based event storage and search
- **Wazuh Dashboard** — Web UI (OpenSearch Dashboards + Wazuh plugin)

Each component runs as its own systemd-managed Docker container with no `docker-compose` dependency.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [`defaults/main.yml`](defaults/main.yml) for the full list of supported options. Refer to [docs/configuring-wazuh.md](docs/configuring-wazuh.md) for setup instructions.

💡 For an Ansible playbook which integrates this role and makes it easier to use, see the [Mother-of-All-Self-Hosting Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

## Required variables

You **must** set these before running the role:

| Variable | Description |
| --- | --- |
| `wazuh_indexer_admin_password` | Admin password for the OpenSearch indexer |
| `wazuh_indexer_kibanaserver_password` | `kibanaserver` user password for dashboard→indexer auth |
| `wazuh_indexer_admin_password_salt` | Bcrypt salt for admin password hash (22 chars, non-secret) |
| `wazuh_indexer_kibanaserver_password_salt` | Bcrypt salt for kibanaserver password hash (22 chars, non-secret) |
| `wazuh_manager_api_password` | Wazuh API password for the `wazuh-wui` user |

See [docs/configuring-wazuh.md](docs/configuring-wazuh.md) for guidance on generating passwords and salts.

## Traefik integration

See [docs/configuring-wazuh-traefik.md](docs/configuring-wazuh-traefik.md) for configuring Traefik to front the dashboard.

## Development

You can optionally install [pre-commit](https://pre-commit.com/) so that simple mistakes are checked and noticed before changes are pushed to a remote branch. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.
