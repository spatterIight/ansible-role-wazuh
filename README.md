<!--
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Wazuh Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Wazuh](https://wazuh.com) to run as [Docker](https://www.docker.com/) containers wrapped in systemd services.

The role deploys the full Wazuh single-node topology:

- **Wazuh Manager** — SIEM engine, agent enrollment, rules engine, Filebeat forwarder
- **Wazuh Indexer** — OpenSearch-based event storage and search
- **Wazuh Dashboard** — Web UI (OpenSearch Dashboards + Wazuh plugin)

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [`defaults/main.yml`](defaults/main.yml) for the full list of supported options. Refer to [docs/configuring-wazuh.md](docs/configuring-wazuh.md) for setup instructions.

💡 For an Ansible playbook which integrates this role and makes it easier to use, see the [Mother-of-All-Self-Hosting Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

## Development

You can optionally install [pre-commit](https://pre-commit.com/) so that simple mistakes are checked and noticed before changes are pushed to a remote branch. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.
