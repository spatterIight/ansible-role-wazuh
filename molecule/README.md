<!--
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

## Installation

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

### `default`

Tests a simple Wazuh installation with no-added bells or whistles.

### `features`

Tests an advanced Wazuh installation with several optional variables configuration:

- `wazuh_agent_conf`
- `wazuh_rules`
- `wazuh_integrations`

## Running

Ubuntu 26.04:

```bash
molecule test --scenario-name default
molecule test --scenario-name features
```

Other distributions:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name features

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default
MOLECULE_DISTRO=debian13 molecule test --scenario-name features
```
