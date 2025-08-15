FROM ubuntu:latest

ARG TZ=Etc/UTC

COPY setup.sh /usr/local/bin/setup.sh
RUN mkdir -p /nfs
RUN chmod +x /usr/local/bin/setup.sh && /usr/local/bin/setup.sh
COPY start-services.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-services.sh

VOLUME /nfs

ENTRYPOINT ["/usr/local/bin/start-services.sh"]