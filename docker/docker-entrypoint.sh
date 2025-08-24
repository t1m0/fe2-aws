#!/bin/sh
# This script is a wrapper that generates config.env before starting the main application.
set -e

# Copy default logback.xml if it doesn't exist in the config volume.
# This provides a default configuration without overwriting user customizations.
LOGBACK_CONFIG_PATH="/Config/data/logback.xml"
DEFAULT_LOGBACK_PATH="/opt/fe2/defaults/logback.xml"

if [ ! -f "$LOGBACK_CONFIG_PATH" ]; then
  echo "No logback.xml found in config volume, copying default from ${DEFAULT_LOGBACK_PATH}."
  # Ensure the target directory exists before copying
  mkdir -p "$(dirname "$LOGBACK_CONFIG_PATH")"
  cp "$DEFAULT_LOGBACK_PATH" "$LOGBACK_CONFIG_PATH"
fi

# The application requires a machine-id. In container environments like Fargate,
# we can't mount the host's machine-id. Instead, we generate a unique one
# for the container's lifetime.
# To support persistent licenses tied to the machine-id, we persist it in the Config volume.
MACHINE_ID_PATH="/etc/machine-id"
PERSISTED_MACHINE_ID_PATH="/Config/machine-id"

if [ -f "$PERSISTED_MACHINE_ID_PATH" ]; then
    echo "Found persisted machine-id at ${PERSISTED_MACHINE_ID_PATH}, using it."
    cp "$PERSISTED_MACHINE_ID_PATH" "$MACHINE_ID_PATH"
else
    echo "No persisted machine-id found. Generating new one..."
    # Generate a 32-character hex string without dashes
    cat /proc/sys/kernel/random/uuid | tr -d '-' > "$MACHINE_ID_PATH"
    
    # Persist it for future boots
    echo "Persisting machine-id to ${PERSISTED_MACHINE_ID_PATH}..."
    cp "$MACHINE_ID_PATH" "$PERSISTED_MACHINE_ID_PATH"
fi

echo "--- Listing root directory for debugging ---"
ls -la /
echo "------------------------------------------"

exec java -jar /fe2.jar server