<!--
SPDX-FileCopyrightText: 2025 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Configuring Wazuh with Traefik

The Wazuh Dashboard can be fronted by Traefik using the label-based routing approach standard in this role collection.

## Basic configuration

```yaml
wazuh_dashboard_container_labels_traefik_enabled: true
wazuh_dashboard_container_labels_traefik_docker_network: traefik
wazuh_dashboard_container_labels_traefik_hostname: wazuh.example.com
```

With these settings the dashboard is reachable at `https://wazuh.example.com` via Traefik's `web-secure` entrypoint with automatic TLS via the `default` cert resolver.

## Key variables

| Variable | Default | Description |
| --- | --- | --- |
| `wazuh_dashboard_container_labels_traefik_enabled` | `true` | Enable Traefik label generation |
| `wazuh_dashboard_container_labels_traefik_docker_network` | `""` | Docker network Traefik is on (required when enabled) |
| `wazuh_dashboard_container_labels_traefik_hostname` | `""` | Hostname to route (required when enabled) |
| `wazuh_dashboard_container_labels_traefik_rule` | `Host(...)` | Full Traefik router rule (auto-derived from hostname) |
| `wazuh_dashboard_container_labels_traefik_entrypoints` | `web-secure` | Traefik entrypoint(s) |
| `wazuh_dashboard_container_labels_traefik_tls` | `true` | Enable TLS on the router |
| `wazuh_dashboard_container_labels_traefik_tls_certResolver` | `default` | Cert resolver name |
| `wazuh_dashboard_container_labels_traefik_priority` | `0` | Router priority (0 = Traefik default) |
| `wazuh_dashboard_container_labels_traefik_path_prefix` | `/` | Path prefix (adds strip-prefix middleware when not `/`) |
| `wazuh_dashboard_container_labels_traefik_additional_response_headers` | `{}` | Extra response headers to inject |
| `wazuh_dashboard_container_labels_additional_labels` | `""` | Freeform extra labels appended to the label file |

## Custom entrypoint and cert resolver

```yaml
wazuh_dashboard_container_labels_traefik_entrypoints: web-secure
wazuh_dashboard_container_labels_traefik_tls_certResolver: letsencrypt
```

## Disabling Traefik

When `wazuh_dashboard_container_labels_traefik_enabled: false`, no Traefik labels are written. The label file is still rendered and passed to the container (so non-Traefik labels in `wazuh_dashboard_container_labels_additional_labels` still work), but Traefik will not route to the dashboard.

In this case you must either expose the dashboard directly with a host port:

```yaml
wazuh_dashboard_http_host_bind_port: "5601"
```

or arrange routing through another reverse proxy.

## Adding custom response headers

```yaml
wazuh_dashboard_container_labels_traefik_additional_response_headers:
  X-Frame-Options: SAMEORIGIN
  X-Content-Type-Options: nosniff
```
