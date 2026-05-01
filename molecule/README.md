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

## Running

Ubuntu 24.04 (default):

```bash
molecule test --scenario-name default
```

Other distributions:

```bash
# Ubuntu 22.04
MOLECULE_DISTRO=ubuntu2204 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
