#!/usr/bin/env bash

set -e

/usr/local/bin/tootctl media remove -days 7 --verbose
/usr/local/bin/tootctl media remove -days 7 --verbose --prune-profiles
/usr/local/bin/tootctl media remove -days 7 --verbose --remove-headers

/usr/local/bin/tootctl preview_cards remove --days 30 --verbose
