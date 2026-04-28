<!--
SPDX-FileCopyrightText: 2025 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Configuring Wazuh

## Quickstart

A minimal inventory entry enabling all three components:

```yaml
wazuh_enabled: true

# Required passwords
wazuh_indexer_admin_password: "your-admin-password"
wazuh_indexer_kibanaserver_password: "your-kibanaserver-password"
wazuh_indexer_admin_password_salt: "your22charsalthere123a"
wazuh_indexer_kibanaserver_password_salt: "another22charsalt12345"
wazuh_manager_api_password: "your-api-password"

# Dashboard Traefik configuration
wazuh_dashboard_container_labels_traefik_enabled: true
wazuh_dashboard_container_labels_traefik_docker_network: traefik
wazuh_dashboard_container_labels_traefik_hostname: wazuh.example.com
```

Run with:

```
ansible-playbook --tags setup-wazuh site.yml
```

Then restart the services:

```
systemctl restart wazuh-indexer wazuh-manager wazuh-dashboard
```

## Generating passwords and salts

Generate strong passwords using `pwgen`:

```bash
pwgen -ycnsB 24 --remove-chars='$&'
```

**Bcrypt salts** are 22 characters long. They must contain only characters from the bcrypt alphabet (`./A-Za-z0-9`). The salts are not secret — they are stored in plaintext in the config. Set them once and keep them stable; changing a salt will change the bcrypt hash, requiring a manual password reset in OpenSearch.

Example salt generation:

```bash
python3 -c "import bcrypt; print(bcrypt.gensalt().decode())" | cut -c8-29
```

## Component flags

Each component can be enabled or disabled independently:

```yaml
wazuh_manager_enabled: true   # default
wazuh_indexer_enabled: true   # default
wazuh_dashboard_enabled: true # default
```

Disabling the entire role:

```yaml
wazuh_enabled: false
```

## External indexer mode

To use an external OpenSearch/Wazuh indexer instead of the bundled one:

```yaml
wazuh_indexer_enabled: false
wazuh_manager_indexer_url: "https://my-external-indexer:9200"
wazuh_manager_indexer_username: admin
wazuh_manager_indexer_password: "external-password"
```

## Agent enrollment

By default agents enroll without a password. To require a password:

```yaml
wazuh_enrollment_password: "your-enrollment-password"
```

Set `wazuh_enrollment_password: ""` (empty string) to disable password-based enrollment.

The enrollment password is stored in `{{ wazuh_data_path }}/manager/etc/authd.pass` and mounted into the manager container at startup.

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

Rule files are written to `{{ wazuh_data_path }}/manager/etc/rules/` and mounted into the container.

## Central agent configuration

Push configuration to all agents via `agent.conf`:

```yaml
wazuh_agent_labels_conf: |
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
```

## Custom integrations

Copy integration scripts (e.g. Python or shell scripts) into the manager's integrations directory:

```yaml
wazuh_integrations:
  - name: custom-slack
    src: /path/on/controller/custom-slack
    mode: "0750"
  - name: custom-slack.py
    src: /path/on/controller/custom-slack.py
    mode: "0750"
```

See `files/integrations/examples/` for example scripts to use as a starting point.

## ossec.conf customization

The manager's `ossec.conf` is managed via XPath replacements. Add your own:

```yaml
wazuh_manager_ossec_xml_replacements_custom:
  - xpath: "/ossec_config/global/email_notification"
    value: "yes"
  - xpath: "/ossec_config/global/email_to"
    value: "alerts@example.com"
```

## Indexer YAML customization

Override any OpenSearch setting:

```yaml
wazuh_indexer_opensearch_yml_extension_yaml: |
  plugins.security.ssl.http.enabled: true
```

## Certificate regeneration

Certificates are generated once and tracked by a sentinel file at `{{ wazuh_certs_path }}/.generated`. To regenerate:

```bash
rm /wazuh/certs/.generated
# Then re-run the playbook
ansible-playbook --tags setup-wazuh site.yml
```

After regeneration, restart all three services.

## Version upgrade procedure

1. Update `wazuh_version` in your inventory.
2. Re-run the playbook: `ansible-playbook --tags setup-wazuh site.yml`.
3. Restart services: `systemctl restart wazuh-indexer wazuh-manager wazuh-dashboard`.

The upstream `wazuh_manager.conf` XML in `files/conf/manager/wazuh_manager.conf` is pinned at the version bundled with this role. After a major version bump, check upstream for config schema changes and update accordingly.
