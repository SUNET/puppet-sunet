#!/bin/bash

mysql -N -B -e "show status like 'wsrep_cluster_size'"
