<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2023 Niels Bouma
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2023, 2024 Gergely Horváth
SPDX-FileCopyrightText: 2023, 2024 MASH project contributors
SPDX-FileCopyrightText: 2024 Philipp Homann
SPDX-FileCopyrightText: 2024 Thomas Miceli
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2025 IUCCA
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Wazuh

This is an [Ansible](https://www.ansible.com/) role which installs [Wazuh](https://wazuh.com/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Wazuh is an open source security platform .

See the project's [documentation](https://documentation.wazuh.com/current/index.html) to learn what Wazuh does and why it might be useful to you.

## Prerequisites

To deploy Wazuh using this role it is necessary that:

1. The [community.general](https://github.com/ansible-collections/community.general) collection be installed. This is needed to support modifying XML configuration files.
2. The [ansible.posix](https://github.com/ansible-collections/ansible.posix) collection be installed. This is needed to support modifying the sysctl `vm.max_map_count` setting.

## Adjusting the playbook configuration

To enable Wazuh with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# wazuh                                                                #
#                                                                      #
########################################################################

wazuh_enabled: true

# Passwords used to authenticate with the dashboard and for components to authenticate between each other
# Generate them using `pwgen -s 63 3`, and manually include at least one special character, or some other way.
wazuh_indexer_admin_password: ""
wazuh_indexer_kibanaserver_password: ""
wazuh_manager_api_password: ""

# Salt's used to hash the above passwords idempotently. Must be exactly 22 characters.
# Generate one using `pwgen -s 22 2`, or some other way
wazuh_indexer_admin_password_salt: ""
wazuh_indexer_kibanaserver_password_salt: ""

########################################################################
#                                                                      #
# /wazuh                                                               #
#                                                                      #
########################################################################
```

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Wazuh becomes available at the specified hostname like `https://example.com`.

To get started, open the URL with a web browser to log in to the dashboard.

To log in to the dashboard use the `admin` username and your `wazuh_indexer_admin_password` configured credential.

### Exposing ports

By default no ports are exposed, but you'll most likely want to adjust this. The below defines what these ports are and why you may want to expose them:

```yaml
# Used by the agent for initial enrollment, you'll probably want to set this
wazuh_manager_agent_host_bind_port: 1514

# Used by the agent to stream events to the manager, you'll probably want to set this
wazuh_manager_authd_host_bind_port: 1515

# Syslog input, you probably don't need this
wazuh_manager_syslog_host_bind_port: 514

# Access to the Wazuh manager REST API, you probably don't need this
wazuh_manager_api_host_bind_port: 55000
```

See the [upstream documentation](https://documentation.wazuh.com/current/getting-started/architecture.html#required-ports) for the full list of Wazuh ports and their purposes.

## External indexer mode

To use an external OpenSearch/Wazuh indexer instead of the bundled one:

```yaml
wazuh_indexer_enabled: false
wazuh_manager_indexer_url: "https://my-external-indexer:9200"
wazuh_manager_indexer_username: admin
wazuh_manager_indexer_password: "external-password"
```

## Agent enrollment

By default agents can enroll without a password. To require a password:

```yaml
wazuh_enrollment_password: "your-enrollment-password"
```

See the [docs](https://documentation.wazuh.com/current/user-manual/agent/agent-enrollment/security-options/using-password-authentication.html) for more information.

## Custom rules

Add custom Wazuh rules via the `wazuh_rules` variable:

```yaml
wazuh_rules:
  - file: my_custom_rules.xml
    contents: |
      <group name="local,custom">
        <rule id="100001" level="3">
          <match>my pattern</match>
          <description>My custom rule</description>
        </rule>
      </group>
```

## Centralized configuration (agent.conf)

Set `wazuh_agent_conf` to configure the agent.conf file:

```yaml
wazuh_agent_conf: |
  <agent_config name="92603de31548">
    <labels>
      <label key="aws.instance-id">i-052a1838c</label>
      <label key="aws.sec-group">sg-1103</label>
      <label key="network.ip">172.17.0.0</label>
      <label key="network.mac">02:42:ac:11:00:02</label>
      <label key="installation" hidden="yes">July 1st, 2024</label>
    </labels>
  </agent_config>
```

See the [docs](https://documentation.wazuh.com/current/user-manual/reference/centralized-configuration.html) for more information and what can be configured here.

## Custom integrations

Wazuh integrations forward alerts to external HTTP webhooks. Any service that accepts an HTTP POST with a JSON body can be used; the `custom-element` scripts included with this role target an [Element](https://element.io/) room via a [maubot](https://github.com/maubot/maubot) bot, like [alertbot](https://github.com/moan0s/alertbot).

**Step 1 — deploy the integration scripts** using `wazuh_integrations`:

```yaml
wazuh_integrations:
  - name: custom-element
    src: "{{ role_path }}/files/integrations/element/custom-element"
    mode: "0750"
  - name: custom-element.py
    src: "{{ role_path }}/files/integrations/element/custom-element.py"
    mode: "0750"
```

**Step 2 — register the integration in `ossec.conf`** using `wazuh_manager_ossec_xml_replacements_custom`:

```yaml
wazuh_manager_ossec_xml_replacements_custom:
  - xpath: "/ossec_config/integration/name"
    value: "custom-element"
  - xpath: "/ossec_config/integration/hook_url"
    value: "https://matrix.domain.com/_matrix/maubot/plugin/alertbot/webhook/YOUR-ROOM-ID"
  - xpath: "/ossec_config/integration/alert_format"
    value: "json"
  - xpath: "/ossec_config/integration/level"
    value: "10"
```

- `name` must match the `name` field in `wazuh_integrations` — that is how Wazuh locates and executes the script.
- `hook_url` can be any HTTPS endpoint that accepts a JSON POST (Element/maubot, Slack, Discord, a generic ingest service, etc.). The URL above is an example Element/maubot webhook — replace `YOUR-ROOM-ID` with your room's Matrix ID.
- `level` sets the minimum alert severity to forward; `10` sends all alerts at level 10 or higher.

See the [upstream documentation](https://documentation.wazuh.com/current/user-manual/manager/integration-with-external-apis.html#custom-integration) for the full list of `<integration>` options.

## Deploying agents via wazuh-ansible

The [wazuh/wazuh-ansible](https://github.com/wazuh/wazuh-ansible) repository provides an official Ansible role for installing the Wazuh agent on managed hosts. It is best used as a git submodule checked out to the same version tag as your Wazuh server.

Add the submodule to your playbook repository:

```sh
git submodule add https://github.com/wazuh/wazuh-ansible.git submodules/wazuh-ansible
git -C submodules/wazuh-ansible checkout v<your-wazuh-version>
```

Then extend your `ansible.cfg` roles path so Ansible can locate the agent role:

```ini
[defaults]
roles_path = ./roles:./submodules/wazuh-ansible/roles/wazuh
```

Add the following to the relevant host or group vars (adjust the `address` if the agent host differs from the Wazuh server - `127.0.0.1` assumes the agent is being deployed to the same server):

```yaml
wazuh_managers:
  - address: 127.0.0.1
    port: 1514
    protocol: tcp
```

> [!TIP]
> If you specified a `wazuh_enrollment_password` in your Wazuh server installation you can configure your agent to provide it via the `authd_pass` variable

Finally, deploy the `ansible-wazuh-agent` role to your target host -- once it finishes you should see the agent show as enrolled in the dashboard!

## Troubleshooting

User guide is available on [this page](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/troubleshooting.html).

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu wazuh-(manager/dashboard/indexer)` (or how you/your playbook named the service, e.g. `mash-wazuh-(manager/dashboard/indexer)`).
