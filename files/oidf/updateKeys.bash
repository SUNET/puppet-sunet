#!/usr/bin/env bash
docker exec -t oidf-ta-admin-1 python manage.py regenerate_entity
docker exec -t oidf-ta-admin-1 python manage.py renew_subordinates