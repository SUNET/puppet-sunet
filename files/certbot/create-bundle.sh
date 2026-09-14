#!/usr/bin/env bash

set -euo pipefail

install -m 640 \
    "${RENEWED_LINEAGE}/privkey.pem" \
    "/tmp/bundle.pem"
cat "${RENEWED_LINEAGE}/fullchain.pem" >> /tmp/bundle.pem
mv /tmp/bundle.pem "${RENEWED_LINEAGE}/"