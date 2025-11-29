#!/usr/bin/env sh
#
# Setup the project.
#
# This script will:
# - Install and configure git hooks

# Install and configure git hooks
echo "Installing git hooks..."
git config core.hooksPath .githooks

# Replace placeholders in config.plist with values from .env (if present)
if [ -f .env ]; then
    echo "Replacing placeholders in AppTelemetry/Sources/AppTelemetry/config.plist..."
    
    # Extract values from .env, trimming whitespace and quotes
    POSTHOG_API_KEY=$(grep -E '^POSTHOG_API_KEY=' .env | cut -d '=' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']*$//')
    POSTHOG_HOST=$(grep -E '^POSTHOG_HOST=' .env | cut -d '=' -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']*$//')
    
    # Validate that we got the values
    if [ -z "$POSTHOG_API_KEY" ] || [ -z "$POSTHOG_HOST" ]; then
        echo "Error: Failed to extract POSTHOG_API_KEY or POSTHOG_HOST from .env"
        exit 1
    fi
    
    # Export variables so perl can access them via %ENV
    export POSTHOG_API_KEY POSTHOG_HOST
    
    # Replace placeholders in-place (backup with .bak extension)
    perl -pi.bak -e 's/{{posthog_api_key}}/$ENV{POSTHOG_API_KEY}/g' AppTelemetry/Sources/AppTelemetry/config.plist
    perl -pi.bak -e 's/{{posthog_host}}/$ENV{POSTHOG_HOST}/g' AppTelemetry/Sources/AppTelemetry/config.plist
    
    # Remove backup file
    rm -f AppTelemetry/Sources/AppTelemetry/config.plist.bak
    
    echo "✓ Secrets injected successfully"
else
    echo "No .env file found, skipping secret injection"
fi