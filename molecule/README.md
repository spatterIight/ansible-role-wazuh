<!--
SPDX-FileCopyrightText: 2018-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## What this suite changes outside the container

Read this before changing anything under `molecule/`. Almost everything this fleet's Molecule scenarios do stays inside a container. This one does not, in one specific way.

`tasks/install_indexer.yml` raises `vm.max_map_count` to 262144, because OpenSearch refuses to start below that. `vm.max_map_count` is **not a namespaced kernel parameter**, and the scenario's container is privileged, so that write reaches the kernel of the machine running the suite and nothing puts it back. On a GitHub Actions runner that is both necessary (the default there is 65530, too low for the indexer) and harmless (the runner is thrown away). On a workstation it is a permanent change to a machine-wide setting, and it can *lower* the value if your distribution already sets a higher one — Arch, for instance, ships 1048576.

`prepare.yml` records the value it found and `verify.yml` asserts the value the role left is at least 262144, reporting both. That is the honest boundary: the suite proves the parameter ended up high enough for OpenSearch, and it tells you what it was before, but it cannot prove the role was the one that raised it on a machine that was already above the threshold.

The same shared-kernel property has a second consequence, and it is the one that will waste your afternoon. `geerlingguy/docker-ubuntu2604-ansible` ships systemd 259, which ships `/usr/lib/sysctl.d/55-map-count.conf` setting `vm.max_map_count=1048576`. `systemd-sysctl.service` applies that at container boot, and because the parameter is not namespaced, it lands on the shared kernel. On a CI runner, where this scenario's container is the only one, that happens once during `create` and the role overwrites it during `converge`, so `molecule test`'s idempotence step sees the role's own value and passes. On a workstation running several privileged systemd containers in parallel — several of this fleet's Molecule scenarios at once, say — every one of them that boots resets the parameter to 1048576 behind this scenario's back, `ansible.posix.sysctl` finds a value it did not set, and the idempotence step fails on `Ensure vm.max_map_count is set for OpenSearch` alone.

That failure is an artifact of the machine, not of the role. If you hit it, run `molecule converge` followed by `molecule verify` instead of `molecule test`, or run this scenario on its own.

If you run this suite locally, note the value first and restore it afterwards:

```bash
sysctl -n vm.max_map_count                       # before
molecule test --scenario-name default
sudo sysctl -w vm.max_map_count=<the old value>  # after
```

## What a green run proves

- **That the running stack is the version the role pins.** None of the four images carry an OCI label, so the version is read out of the running containers: `VERSION.json` for the indexer and the dashboard, `wazuh-control info` for the manager, and the manager's own REST API for a fourth, process-level reading.
- **That the indexer is running the configuration this role rendered, and nobody else's.** The image ships its own `opensearch.yml` which is a near-clone of what this role renders, so the assertions pick settings that differ: the port *ranges* (`9200-9299`, `9300-9399`, which the image's file does not set at all) and the certificate filename (`wazuh.indexer.pem`, where the image says `indexer.pem`). They are read back from `_nodes/_local/settings`, which is the node's running configuration rather than a file on disk.
- **That the indexer's security database is the one this role rendered.** Every request to the indexer is authenticated as `admin` with the password the scenario configured. The image ships a demo `internal_users.yml` whose `admin` hash is for the well-known `SecretPassword`; if the role's rendered file had not replaced it, those requests would come back 401. A companion request with a deliberately wrong password asserts that a 401 is what a wrong password gets, so the first assertion cannot pass against an indexer that authenticates nobody.
- **That the manager is running the configuration this role rendered.** The base `wazuh_manager.conf` this role ships already carries the indexer URL, so asserting on that would prove nothing. The scenario sets a custom XPath replacement (`email_from`) that only `tasks/install_manager.yml` could have produced, and relies on `wazuh_enrollment_password` flipping `use_password` from `no` to `yes`. Both are read back through the manager's REST API, out of the running process.
- **That `API_PASSWORD` reached the manager process.** The API is authenticated with the password the scenario configured, and rejects a wrong one.
- **That the dashboard reached the indexer.** Established by hand against the image: with no configuration the dashboard exits before it listens at all, and with a configuration pointing at an indexer it cannot reach it answers `503 Wazuh dashboard server is not ready yet` on *every* path, `/app/login` included. A 200 is therefore not a wizard page or a login form rendering over a broken backend.
- **That `wazuh_dashboard_http_port` reaches the process.** The scenario sets it to 5602 rather than the role's default 5601, and publishes that container port on 5699. If the value failed to reach `server.port` in the rendered `opensearch_dashboards.yml`, the dashboard would listen on 5601 and nothing would answer on 5699.
- **That the Traefik labels, the additional volumes and the extra container arguments are real.** Read back from `docker container inspect`: the router rule with the scenario's hostname and path prefix, the strip-prefix middleware, the load balancer port, the Traefik network the unit's `ExecStartPre` connects to, both accepted shapes of `*_container_additional_volumes` (including that a read-only mount really is read-only), and a label injected through `*_container_extra_arguments`.
- **That the manager-side features are installed.** The enrollment password file, the remote `agent.conf`, the custom rule file, and the custom integrations with the `root:wazuh` ownership and `0750` mode `wazuh-integratord` insists on.

## What it does not prove

- **Anything about upgrading.** This is a fresh install every time. The indexer keeps a persistent OpenSearch data directory and a security index that is initialized once from `internal_users.yml` and never read again; none of that is exercised by installing from nothing.
- **That an agent can actually enrol.** No agent is started. What is asserted is that the manager is running with `use_password` on and that `authd.pass` carries the configured password.
- **That the rules and integrations do anything.** They are asserted to be installed where and how the manager expects them, not to fire.
- **Uninstallation.** `tasks/uninstall.yml` has no scenario.

## Scenarios

Currently one testing scenario is available.

### `default`

The whole role: manager, indexer, dashboard and the certificate generator, with Traefik labels, agent enrollment, a remote agent configuration, a custom rule, custom integrations, additional volumes, extra container arguments and a custom `ossec.conf` XPath replacement.

There used to be a second scenario, `features`, which configured the optional variables. Its `verify.yml` was byte-for-byte identical to `default`'s apart from two task names, so it asserted none of the features it configured; every one of them is now asserted here instead.

Nearly every value the scenario sets differs from the role's own default, so that a value observed on the running stack can be told apart from one the container image or the role default produced.

## Running

By default it is configured to run the scenario on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default
```
