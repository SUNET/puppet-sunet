#!/bin/bash

echo -n "init_type="
(test ! -z `pidof init | awk '{print $NF}'` && echo init) || (test ! -z `pidof systemd | awk '{print $NF}'` && echo systemd) || echo unknown
