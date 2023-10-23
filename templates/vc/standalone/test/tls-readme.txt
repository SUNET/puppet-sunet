RUN: mkdir letsencrypt && cd letsencrypt

FILE: docker-compose.yaml
'
version: '3'

services:
  webserver:
    image: nginx:latest
    ports:
      - 80:80
      - 443:443
    restart: always

networks:
  default:
    driver_opts:
      com.docker.network.bridge.name: br-certbot

'

RUN: docker-compose up -d

RUN: docker exec -ti letsencrypt_webserver_1 bash
# Or whatever the container is called to get into it with a root bash shell

# Inside container
RUN: apt-get update && apt install certbot python3-certbot-nginx zip

ADD: vc-test-1.sunet.se to server_name config in /etc/nginx/conf.d/default.conf

RUN: certbot --nginx -d vc-test-1.sunet.se

# CERTS AND ALL LETSENCRYPT are in /etc/letsencrypt/

RUN: cd /etc && zip -r /letsencrypt.zip letsencrypt/

# Exit the container
RUN: docker cp letsencrypt_webserver_1:/letsencrypt.zip .

# The cert and key are in the 'live' folder in the zip file

# Create the fullchain cert + key file for haproxy with something like this into 'cert' in vc project folder
unzip letsencrypt.zip && cat letsencrypt/live/vc-test-1.sunet.se/fullchain.pem letsencrypt/live/vc-test-1.sunet.se/privkey.pem | tee cert/tls-cert-key.pem
