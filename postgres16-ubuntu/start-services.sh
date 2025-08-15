#!/bin/bash

# Start the SSH service
service ssh start

# Start the PostgreSQL service
# This command might vary based on how PostgreSQL was installed
service postgresql start


# Keep the container running after the services have been started
tail -f /dev/null
