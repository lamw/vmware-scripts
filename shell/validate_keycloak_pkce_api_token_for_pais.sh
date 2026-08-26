#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# KEYCLOAK CONFIGURATION
# Adjust these variables to match your environment
# ==============================================================================
KEYCLOAK_HOST="https://vis.vcf.lab:9444"
REALM="VCF"
CLIENT_ID="pais"
REDIRECT_URI="https://pais.vcf.lab/"
SCOPES="openid profile email"

# Base Endpoints
AUTH_ENDPOINT="${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/auth"
TOKEN_ENDPOINT="${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token"

# ==============================================================================
# STEP 1: GENERATE PKCE VERIFIER AND CHALLENGE
# ==============================================================================
echo "=================================================="
echo "Generating PKCE Verifier and Challenge..."
echo "=================================================="

# 1. Generate 32 bytes of random string and base64url encode it (Code Verifier)
CODE_VERIFIER=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=')

# 2. SHA-256 hash the verifier and base64url encode it (Code Challenge)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | openssl base64 -e | tr '+/' '-_' | tr -d '=' | tr -d '\n')

echo "Code Verifier : $CODE_VERIFIER"
echo "Code Challenge: $CODE_CHALLENGE"
echo ""

# ==============================================================================
# STEP 2: BUILD AUTHORIZATION URL
# ==============================================================================
# URL encode the scope parameter
ENCODED_SCOPES=$(echo -n "$SCOPES" | sed 's/ /%20/g')

LOGIN_URL="${AUTH_ENDPOINT}?client_id=${CLIENT_ID}&response_type=code&redirect_uri=${REDIRECT_URI}&scope=${ENCODED_SCOPES}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo "=================================================="
echo "ACTION REQUIRED: Open this URL in your browser"
echo "=================================================="
echo "$LOGIN_URL"
echo "=================================================="
echo ""

# ==============================================================================
# STEP 3: CAPTURE THE CODE & EXCHANGE FOR TOKEN
# ==============================================================================
# Prompt user to input either the full redirect URL or just the code parameter
read -rp "Paste the 'code' parameter (or full redirect URL) here: " RAW_INPUT

# Extract just the code parameter if the full URL was pasted
if [[ "$RAW_INPUT" == *"code="* ]]; then
  AUTH_CODE=$(echo "$RAW_INPUT" | sed -n 's/.*code=\([^&]*\).*/\1/p')
else
  AUTH_CODE="$RAW_INPUT"
fi

if [[ -z "$AUTH_CODE" ]]; then
  echo "Error: Authorization code cannot be empty." >&2
  exit 1
fi

echo ""
echo "Exchanging authorization code for Access Token..."

# Execute POST request to Keycloak /token endpoint
RESPONSE=$(curl -k -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${CODE_VERIFIER}")

echo ""
echo "=================================================="
echo "Keycloak Response Payload:"
echo "=================================================="

# Print raw JSON or pretty print if python3/jq is installed
if command -v jq &> /dev/null; then
  echo "$RESPONSE" | jq .
elif command -v python3 &> /dev/null; then
  echo "$RESPONSE" | python3 -m json.tool
else
  echo "$RESPONSE"
fi