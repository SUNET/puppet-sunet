#!/bin/bash

type=$(dpkg -S /sbin/init | awk -F: '{print $1}')
echo "init_type=$type"
