#!/usr/bin/env bash
#
# Generate a self-signed X.509 certificate and private key for the JWT bearer
# OAuth flow used by GitHub Actions to authenticate to Salesforce.
#
# Output (written to ci/keys/, which is git-ignored):
#   server.key   -> upload the CONTENTS as a GitHub secret (SFDX_JWT_KEY_<env>)
#   server.crt   -> upload this FILE to the Salesforce Connected App
#                   under "Use digital signatures"
#
# Usage:
#   ./scripts/ci/generate-jwt-cert.sh [env-name]
#
# Example:
#   ./scripts/ci/generate-jwt-cert.sh sit
#
# The env-name is only used to organise output files. You can regenerate keys
# per environment if you want unique credentials for SIT / UAT / PROD.

set -euo pipefail

ENV_NAME="${1:-sit}"
OUT_DIR="ci/keys/${ENV_NAME}"

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

if [ -f server.key ] || [ -f server.crt ]; then
  echo "!! ${OUT_DIR}/server.key or server.crt already exists."
  echo "   Move them aside or delete before regenerating."
  exit 1
fi

echo ">> Generating 2048-bit RSA private key and self-signed certificate"
echo "   (valid for 10 years, CN=Bedrock DevSecOps CI - ${ENV_NAME})"
echo ""

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -days 3650 \
  -nodes \
  -keyout server.key \
  -out server.crt \
  -subj "/C=US/ST=NA/L=NA/O=Bedrock/OU=DevSecOps/CN=Bedrock DevSecOps CI - ${ENV_NAME}"

chmod 600 server.key
chmod 644 server.crt

echo ""
echo "OK - Files written to ${OUT_DIR}/"
echo ""
ls -la
echo ""
echo "Next steps:"
echo "  1. Upload server.crt to your Salesforce Connected App"
echo "     (Setup -> App Manager -> New Connected App ->"
echo "      Enable OAuth Settings -> Use digital signatures)."
echo ""
echo "  2. Copy the Consumer Key from the Connected App and save it as"
echo "     GitHub secret SFDX_CONSUMER_KEY_$(echo "${ENV_NAME}" | tr '[:lower:]' '[:upper:]')."
echo ""
echo "  3. Copy the ENTIRE contents of server.key (including the"
echo "     -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY----- lines)"
echo "     and save as GitHub secret SFDX_JWT_KEY_$(echo "${ENV_NAME}" | tr '[:lower:]' '[:upper:]')."
echo ""
echo "  4. See .github/CI-CD-JWT-Setup.md for the full walk-through."
echo ""
echo "SECURITY: server.key must NEVER be committed. It is already covered by .gitignore."
