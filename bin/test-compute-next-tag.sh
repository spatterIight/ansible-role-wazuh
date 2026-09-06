#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Wazuh 4.14.7 which has already seen
# one release of it (v4.14.7-0), plus the older releases this repository really
# carries.
#
# The defaults file deliberately reproduces the traps the real one has:
#
# - a `# renovate:` annotation directly above the version, so that a future
#   refactor which moved the annotation onto a different variable would have to
#   move it here too and would be caught by the scenarios below;
# - three `*_container_image_tag` variables derived from `wazuh_version`, whose
#   Jinja value would produce a nonsense tag if one of them were read instead;
# - a fourth `*_container_image_tag` which is a literal of a *different*
#   component (the certificate generator) on its own version line, which must
#   never be mistaken for the Wazuh version;
# - a commented-out example of the version variable.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/files" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# wazuh_version: 9.9.9

		# renovate: datasource=docker depName=wazuh/wazuh-manager
		wazuh_version: "4.14.7"

		wazuh_manager_container_image_tag: "{{ wazuh_version }}"
		wazuh_indexer_container_image_tag: "{{ wazuh_version }}"
		wazuh_dashboard_container_image_tag: "{{ wazuh_version }}"

		# renovate: datasource=docker depName=wazuh/wazuh-certs-generator versioning=semver
		wazuh_certs_generator_container_image_tag: "0.0.4"
	YAML
	printf 'placeholder\n' > files/wazuh-certs-tool.sh
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v4.14.1-0 v4.14.5-0 v4.14.6-0 v4.14.7-0; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version='sed -i "s|^wazuh_version: \"4.14.7\"|wazuh_version: \"4.15.0\"|" defaults/main.yml'
revert_version='sed -i "s|^wazuh_version: \"4.15.0\"|wazuh_version: \"4.14.7\"|" defaults/main.yml'
bump_certs_generator='sed -i "s|^wazuh_certs_generator_container_image_tag: \"0.0.4\"|wazuh_certs_generator_container_image_tag: \"0.0.5\"|" defaults/main.yml'
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_file="printf '# a line\n' >> files/wazuh-certs-tool.sh"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v4.15.0-0 "$(merge "$bump_version")"
expect 'task edit'    v4.15.0-1 "$(merge "$edit_task")"
expect 'template'     v4.15.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v4.14.7-1 "$(merge "$edit_task")"
expect 'version bump' v4.15.0-0 "$(merge "$bump_version")"

# The certificate generator is a second, independently versioned image this
# role deploys. Bumping it is a change to the role, not a new Wazuh release,
# so it must roll the counter rather than restart it - and it must never be
# read as the version, which would produce a `v0.0.5-0` tag.
scenario 'A certificate generator bump'
expect 'certs-generator bump' v4.14.7-1 "$(merge "$bump_certs_generator")"

# `files/` carries the certificate tooling and the manager's base
# configuration, which are as much a part of what the role does as `tasks/`.
scenario 'A change to a shipped file'
expect 'a shipped file' v4.14.7-1 "$(merge "$edit_file")"

scenario 'Commits that do not affect the role'
expect 'README'   ''          "$(merge "$edit_readme")"
expect 'a script' ''          "$(merge "$edit_script")"
expect 'a task'   v4.14.7-1   "$(merge "$edit_task")"

# This repository really carries a v4.14.5-10 and a v4.14.5-11, so a
# lexicographic sort of the release numbers would pick the wrong predecessor.
scenario 'Release numbers past 9'
for release_number in 1 2 3 4 5 6 7 8 9 10; do
	git tag "v4.14.7-$release_number"
done
expect 'a task' v4.14.7-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v4.14.7-0 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v4.14.7-1 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
