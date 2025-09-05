FROM debian:stable-slim

ARG TZ=Etc/UTC

# Install dos2unix to handle line ending issues
RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/*

# Copy shared scripts and CA files
COPY shared/setup.sh /usr/local/bin/
COPY shared/start-services.sh /usr/local/bin/
COPY ca/ /tmp/ca/

# Fix line endings and make executable
RUN dos2unix /usr/local/bin/setup.sh /usr/local/bin/start-services.sh /tmp/ca/*.sh && \
    chmod +x /usr/local/bin/setup.sh /usr/local/bin/start-services.sh /tmp/ca/*.sh && \
    /usr/local/bin/setup.sh

EXPOSE 5432 22

# Create volume for SSL certificates
VOLUME ["/tmp/certs"]

ENTRYPOINT ["/usr/local/bin/start-services.sh"]
