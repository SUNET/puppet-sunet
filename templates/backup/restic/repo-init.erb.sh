#!/bin/bash
# Managed by puppet: sunet::backup::restic::repository['<%= @title %>'] - do not edit
#
# Initialise the repository, but only when restic says it genuinely is not there.
#
# 'restic cat config' fails for several unrelated reasons, and only one of them should
# be answered by creating a repository. Acting on "did it fail" would mean a missing
# bucket, a rotated credential, a wrong password or a network blip could all be
# mistaken for "not initialised yet" - and creating a fresh empty repository in that
# situation is worse than doing nothing, because backups would then succeed into it
# while the history everyone expects sits elsewhere.
#
# So switch on the exit status instead:
#
#    0  already initialised          - nothing to do
#   10  repository does not exist    - initialise it
#   12  wrong password               - leave it alone, report
#    *  unreachable, no credentials,
#       locked, ...                  - leave it alone, report
#
# No 'set -e': the exit status of 'cat config' is the whole point and has to be
# inspected rather than aborted on.
set -uo pipefail

wrapper=<%= @quoted['wrapper'] %>

out=$("${wrapper}" cat config 2>&1)
rc=$?

case "${rc}" in
  0)
    exit 0
    ;;
  10)
    echo "restic repository <%= @safe_name %> does not exist yet - initialising"
    exec "${wrapper}" init
    ;;
  12)
    echo "restic repository <%= @safe_name %> rejected the configured password - refusing to initialise" >&2
    echo "${out}" >&2
    exit "${rc}"
    ;;
  *)
    echo "restic repository <%= @safe_name %> could not be read (exit ${rc}) - refusing to initialise" >&2
    echo "${out}" >&2
    exit "${rc}"
    ;;
esac
