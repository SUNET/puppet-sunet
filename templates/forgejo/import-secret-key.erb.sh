#!/bin/bash
platform_sunet_se_gpg_key="<%= @platform_sunet_se_gpg_key %>"
fingerprint=$(echo "${platform_sunet_se_gpg_key}" | gpg --show-key| head -2 | tail -1 | tr -d ' ')

if ! gpg --list-keys | grep "${fingerprint}"; then
  echo "${platform_sunet_se_gpg_key}" | gpg --batch --import
  echo "${fingerprint}:6" | gpg --import-ownertrust
fi
