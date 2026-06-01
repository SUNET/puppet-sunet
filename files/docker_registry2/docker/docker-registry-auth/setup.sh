#!/bin/bash

set -e
set -x

export DEBIAN_FRONTEND noninteractive

# Use the mirror hosted within SUNET in Sweden
/bin/sed -i 's#deb.debian.org/debian$#ftp.se.debian.org/debian#' /etc/apt/sources.list

# Update the image and install common tools for debugging
# as well as packages needed for this image.
apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get install -y \
      iputils-ping \
      procps \
      bind9-host \
      netcat-openbsd \
      apache2 \
      ssl-cert \
      augeas-tools \
    && apt-get -y autoremove \
    && apt-get autoclean

# Do some more cleanup to save space
rm -rf /var/lib/apt/lists/*

# Remove default config
rm /etc/apache2/sites-enabled/*

# Enable required modules
a2enmod rewrite
a2enmod ssl
a2enmod proxy
a2enmod proxy_http
a2enmod headers

# Disable the status page
a2dismod status

# Enable the config we have specified
a2ensite --maintmode registry-auth-ssl
