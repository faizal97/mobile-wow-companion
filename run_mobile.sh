#!/bin/bash
# Run Flutter on a connected mobile device with dart-defines loaded from .env

# Load secrets from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

flutter run \
  --dart-define=BNET_CLIENT_ID="${BNET_CLIENT_ID}" \
  --dart-define=BNET_REDIRECT_URI="${BNET_REDIRECT_URI}" \
  --dart-define=AUTH_PROXY_URL="${AUTH_PROXY_URL}"
