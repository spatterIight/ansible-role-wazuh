#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<wazuh version>-<release>`, which is what this repository
# has always published (v4.14.1-0 ... v4.14.7-0):
#
# - if defaults/main.yml points at a Wazuh version that has never been
#   released, the release counter restarts at 0 (`v4.15.0-0`)
# - otherwise the counter is incremented (`v4.14.7-1`), but only if something
#   that actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
#
# The commit-message approach this replaced could only ever fire on a commit
# whose subject was written by Renovate and mentioned both "docker tag to" and
# "wazuh". The two most recent Wazuh bumps this repository received
# ("Updated Wazuh, 4.14.5 -> 4.14.6" and "Updated Wazuh, 4.14.6 -> 4.14.7")
# were made by hand and match neither condition, so nothing would have been
# released for them at all.
#
# This role deploys four container images. Three of them (manager, indexer,
# dashboard) derive their tag from `wazuh_version`, which is the one leaf
# literal Renovate edits and the one this script reads. The fourth,
# `wazuh_certs_generator_container_image_tag`, moves on its own schedule; a
# bump of it is a change under `defaults/`, so it rolls the release counter
# rather than restarting it.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
#
# `files` is in the list because this role ships the certificate tooling and
# the manager's base `wazuh_manager.conf` as plain files rather than templates.
role_defining_paths=(
	'defaults'
	'files'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `wazuh_version:` so that neither a commented-out example nor any
# of the `*_container_image_tag` variables can be mistaken for it. Three of
# those are derived from this one (`"{{ wazuh_version }}"`, which would produce
# a nonsense tag if read), and `wazuh_certs_generator_container_image_tag` is a
# literal of an entirely different component.
version="$(sed -nE 's|^wazuh_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the Wazuh version from $defaults_path"
	exit 1
fi

# Wazuh's own version is carried without a leading `v` (the `v` lives only in
# the tags), but tolerate one so that a future change of convention does not
# produce a doubled prefix.
tag_prefix="v${version#v}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9. This repository
# really does carry a v4.14.5-10 and a v4.14.5-11.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
