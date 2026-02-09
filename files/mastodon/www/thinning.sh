#!/usr/bin/env bash

set -e

/usr/local/bin/tootctl tootctl media remove -days 7 --verbose
/usr/local/bin/tootctl tootctl media remove -days 7 --verbose --prune-profiles
/usr/local/bin/tootctl tootctl media remove -days 7 --verbose --remove-headers

/usr/local/bintootctl preview_cards remove --days 30 --verbose
