<!--
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Updating the role for a new Wazuh release

## Overview

Bumping `wazuh_version` in `defaults/main.yml` is not enough on its own. The role ships
upstream Wazuh configuration as:

- **Jinja2 templates** in `templates/` (dashboard, indexer, manager env files, certs config)
- **One static file** in `files/conf/manager/wazuh_manager.conf`
- **Two vendored shell scripts** in `files/` (`wazuh-certs-tool.sh`, `wazuh-certs-entrypoint.sh`)

When Wazuh releases a new version, those files may change. The canonical source for what the
new defaults should look like is the **`single-node/` directory of the
[wazuh/wazuh-docker](https://github.com/wazuh/wazuh-docker) repository**, not the container
image itself.

The templates are deliberately **not** verbatim copies — they substitute credentials, ports,
and hostnames with Jinja2 variables, and some intentionally diverge from upstream defaults
(see each step below). The static `wazuh_manager.conf` can be copied verbatim.

Renovate watches the `wazuh/wazuh-manager` Docker tag and opens version-bump PRs
automatically. Manual reconciliation of configuration files is still required.

## When to run this procedure

On each new upstream Wazuh release.

## Prerequisites

- A working clone of [wazuh/wazuh-docker](https://github.com/wazuh/wazuh-docker)

## Step 1 — Bump `wazuh_version`

Edit `defaults/main.yml` and set `wazuh_version` to the new release. Renovate's PR may
handle this. This single variable drives all three component image tags (manager, indexer,
dashboard) via `wazuh_*_container_image_tag`.

## Step 2 — Check out the matching wazuh-docker tag

```sh
cd /path/to/wazuh-docker
git fetch --tags
git checkout v<new-version>
```

All diffs in the steps below compare files from `single-node/` at this tag against the
role's files.

## Step 3 — Reconcile `files/conf/manager/wazuh_manager.conf`

```sh
diff single-node/config/wazuh_cluster/wazuh_manager.conf \
     ansible-role-wazuh/files/conf/manager/wazuh_manager.conf
```

Default action: copy the new upstream file verbatim.

## Step 4 — Reconcile templates

For each template, diff the corresponding upstream file against the role template and port
any non-Jinja2 changes. Do **not** replace Jinja2 expressions with hardcoded values.

**`templates/dashboard/opensearch_dashboards.yml.j2`**

Source: `single-node/config/wazuh_dashboard/opensearch_dashboards.yml`

```sh
diff single-node/config/wazuh_dashboard/opensearch_dashboards.yml \
     ansible-role-wazuh/templates/dashboard/opensearch_dashboards.yml.j2
```

Preserve these intentional divergences:

- `server.port: {{ wazuh_dashboard_http_port }}` — not the hardcoded `5601`
- `server.ssl.enabled: false` — Traefik terminates TLS for the role; upstream has `true`
- The role uses YAML block-sequence list format (`- "value"`) instead of upstream's inline
  bracket format (`["value"]`)

---

**`templates/dashboard/wazuh.yml.j2`**

Source: `single-node/config/wazuh_dashboard/wazuh.yml`

```sh
diff single-node/config/wazuh_dashboard/wazuh.yml \
     ansible-role-wazuh/templates/dashboard/wazuh.yml.j2
```

Preserve all four Jinja2 substitutions — none of the upstream values should be hardcoded:

- `url: "{{ wazuh_dashboard_api_url }}"`
- `port: {{ wazuh_manager_api_port }}`
- `username: "{{ wazuh_dashboard_api_username }}"`
- `password: "{{ wazuh_dashboard_api_password }}"`

---

**`templates/indexer/wazuh.indexer.yml.j2`**

Source: `single-node/config/wazuh_indexer/wazuh.indexer.yml`

```sh
diff single-node/config/wazuh_indexer/wazuh.indexer.yml \
     ansible-role-wazuh/templates/indexer/wazuh.indexer.yml.j2
```

No Jinja2 variables in this template. Preserve the formatting divergence: the role uses
YAML block-sequence list format for all array values; upstream uses inline bracket format.
Port any added or removed configuration keys verbatim.

Also preserve these two keys, which the role sets and upstream does not:

```yaml
http.port: 9200-9299
transport.tcp.port: 9300-9399
```

---

**`templates/indexer/internal_users.yml.j2`**

Source: `single-node/config/wazuh_indexer/internal_users.yml`

```sh
diff single-node/config/wazuh_indexer/internal_users.yml \
     ansible-role-wazuh/templates/indexer/internal_users.yml.j2
```

Two intentional divergences to preserve:

1. **Passwords are templated**, not literal bcrypt hashes:

   ```yaml
   admin:
     hash: "{{ wazuh_indexer_admin_password | password_hash('bcrypt', salt=wazuh_indexer_admin_password_salt) }}"
   kibanaserver:
     hash: "{{ wazuh_indexer_kibanaserver_password | password_hash('bcrypt', salt=wazuh_indexer_kibanaserver_password_salt) }}"
   ```

2. **The template intentionally omits demo users.** Upstream ships six users; the role keeps
   only `admin` and `kibanaserver`. Do not add `kibanaro`, `logstash`, `readall`, or
   `snapshotrestore`.

---

**`templates/manager/env.j2`, `templates/indexer/env.j2`, `templates/dashboard/env.j2`**

Source: `environment:` blocks in `single-node/docker-compose.yml`

These templates expose the container environment variables that docker-compose sets directly.
Diff each service's `environment:` list against the corresponding `env.j2` to check whether
any variables were added or removed upstream. All values in the role are Jinja2 variables —
do not copy hardcoded credentials from docker-compose.

## Step 5 — Reconcile the vendored certificate-generation scripts

These two files are not covered by the `single-node/` diffs above and are easy to forget.

**`files/wazuh-certs-tool.sh`**

Upstream's certs-generator container does **not** ship this tool — its entrypoint downloads
it at runtime from `https://packages.wazuh.com/$CERT_TOOL_VERSION/wazuh-certs-tool.sh`, where
`CERT_TOOL_VERSION` is set in `single-node/generate-indexer-certs.yml`. The role vendors the
tool instead (and forks the entrypoint to load it from a bind mount), so the vendored copy
does not refresh itself and will silently go stale.

That URL is **branch-level, not per-patch** — `https://packages.wazuh.com/<major.minor.patch>/`
returns 403, so there is no version-to-version diff to take. Compare against the branch URL
for the new release's minor series on every update:

```sh
diff <(curl -fsSL https://packages.wazuh.com/<major.minor>/wazuh-certs-tool.sh) \
     ansible-role-wazuh/files/wazuh-certs-tool.sh
```

Default action: copy the new upstream file verbatim, then re-add the role's only local
modification — the provenance comment after the shebang:

```sh
# Source -> https://packages.wazuh.com/<major.minor>/wazuh-certs-tool.sh
```

Upstream ships a few lines with trailing whitespace; the `trailing-whitespace` pre-commit
hook strips them, so the vendored copy is never byte-identical to the download. Account for
that when diffing. Note also that `.pre-commit-config.yaml` excludes both scripts from
codespell, since they are upstream code.

**Reading the diff:** if the only hunks are trailing whitespace on the
`# ------------ certFunctions.sh ------------` style section separators, the vendored copy is
already current and needs no refresh. The branch URL only changes when upstream reworks the
tool, which is far less often than each patch release — most releases require no action here.

Before accepting a refresh, sanity-check two things that the role depends on:

- Node names in `templates/certs/certs.yml.j2` (`wazuh.indexer`, `wazuh.manager`,
  `wazuh.dashboard`) must still be accepted — recent versions validate them.
- The file must still end in `main "$@"`, and still `mv` its output to
  `${base_path}/wazuh-certificates`. The entrypoint `source`s the tool and then copies from
  `/wazuh-certificates`, so both are load-bearing.

Note that `tasks/certs.yml` skips generation entirely once `{{ wazuh_certs_path }}/.generated`
exists, so a refreshed tool only affects **new** installations. Test it with a Molecule run
rather than against an existing deployment.

While here, check `wazuh_certs_generator_container_image_tag` in `defaults/main.yml` against
the image tag in the same `single-node/generate-indexer-certs.yml`. It is versioned
independently of `wazuh_version` and rarely changes.

---

**`files/wazuh-certs-entrypoint.sh`**

Source: `indexer-certs-creator/config/entrypoint.sh`

```sh
diff indexer-certs-creator/config/entrypoint.sh \
     ansible-role-wazuh/files/wazuh-certs-entrypoint.sh
```

Preserve these intentional divergences:

- The role **loads the cert tool from `/config/`** instead of downloading it from
  `packages.wazuh.com` — the whole download block is replaced by a local-filesystem check.
- The provenance comment near the top pins the upstream tag it was forked from. Bump it to
  the new tag as part of this step.
- Upstream ends the file with a trailing blank line, which the `end-of-file-fixer` pre-commit
  hook strips. That last diff hunk is expected and should be left alone.

## Step 6 — Verify

```sh
just prek-run-on-all
```

Then run both Molecule scenarios, which converge against fresh containers and therefore
exercise certificate generation end to end (see `molecule/README.md` for venv setup):

```sh
molecule test --scenario-name default
molecule test --scenario-name features
```

Deploy against a test host; check `journalctl -u wazuh-manager -u wazuh-indexer -u wazuh-dashboard`
for clean container startup. Verify the Wazuh dashboard is reachable and shows the manager
and indexer as connected.

Before committing, review the full diff:

```sh
git diff defaults/main.yml files/ templates/
```

Changes should be limited to the version bump, refreshed upstream configuration, and the
intentional template and script divergences listed above.
