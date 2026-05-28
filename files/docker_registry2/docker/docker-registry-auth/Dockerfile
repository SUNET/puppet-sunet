FROM debian:bullseye

# Copying the Dockerfile to the image as documentation
COPY Dockerfile /

COPY registry-auth-ssl.conf /etc/apache2/sites-available/registry-auth-ssl.conf
COPY setup.sh /opt/sunet/setup.sh
COPY start.sh /start.sh
RUN /opt/sunet/setup.sh

WORKDIR /

EXPOSE 443

ENV SERVER_NAME docker.example.com
ENV SSLVerifyDepth 1
ENV PROXY_TARGET http://registry:5000

CMD ["bash", "/start.sh"]
