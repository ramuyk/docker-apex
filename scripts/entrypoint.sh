#!/bin/bash
#
# Entrypoint Script
# Orchestrates APEX setup and ORDS startup
#

set -e

echo "=========================================="
echo "Oracle APEX Docker Container Starting"
echo "=========================================="

# Check if we should skip admin setup
if [ "${SKIP_APEX_INSTALL}" = "true" ]; then
    echo "⚠️  SKIP_APEX_INSTALL=true - Skipping admin setup"
    echo "   Assuming APEX is already installed and users exist"
    echo ""
else
    echo "Running admin setup (requires DBA privileges)..."
    echo ""
    /opt/scripts/setup-apex-admin.sh
    echo ""
fi

echo "Running ORDS startup..."
echo ""
/opt/scripts/start-ords.sh