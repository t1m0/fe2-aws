# Inherit from the official FE2 base image
FROM alamosgmbh/fe2:2.38-STABLE

# Install libc6-compat to fix "Error loading shared library ld-linux-x86-64.so.2"
RUN apk add --no-cache libc6-compat

# Copy the default logging configuration into a staging directory in the image
COPY logback.xml /opt/fe2/defaults/logback.xml

# Set the new entrypoint. The CMD from the base image will be passed to this script.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]