#!/usr/bin/env bash

# Make sure that naemon has time to write down retention.dat
/usr/bin/docker exec naemonmonitor_naemon_1 bash -c 'pkill -o naemon'

/usr/local/bin/docker-compose -f /opt//naemon_monitor/docker-compose.yml down
