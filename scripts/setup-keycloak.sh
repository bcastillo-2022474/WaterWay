#!/bin/sh

set -e

# add curl and jq if not present
apk add --no-cache curl jq gettext

echo "Waiting for Keycloak to be ready..."
until curl -s "${KEYCLOAK_URL}/realms/master" > /dev/null; do
  sleep 5
done

echo "Substituting environment variables in realm-import.json..."
envsubst < /scripts/realm-import.json > /scripts/realm.json

echo "Checking if realm already exists..."
if curl -s "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" | grep -q "${REALM_NAME}"; then
  echo "Realm ${REALM_NAME} already exists. Skipping import."
else
  echo "Getting access token..."
  ACCESS_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d 'grant_type=password' \
    -d 'client_id=admin-cli' \
    | jq -r .access_token)

  echo "Importing realm..."
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/scripts/realm.json
fi

echo "Getting access token again..."
ACCESS_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' \
  | jq -r .access_token)

echo "Adding realm roles to the ID token..."
# First, get the client ID
CLIENT_ID_RESPONSE=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

INTERNAL_CLIENT_ID=$(echo "${CLIENT_ID_RESPONSE}" | jq -r '.[0].id')

if [ -z "${INTERNAL_CLIENT_ID}" ] || [ "${INTERNAL_CLIENT_ID}" = "null" ]; then
  echo "Error: Could not find client with ID ${CLIENT_ID}"
  exit 1
fi

echo "Found internal client ID: ${INTERNAL_CLIENT_ID}"

# Check if the protocol mapper already exists
MAPPER_NAME="realm-roles-mapper"
EXISTING_MAPPER=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${INTERNAL_CLIENT_ID}/protocol-mappers/models" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq -r ".[] | select(.name==\"${MAPPER_NAME}\") | .id")

if [ -n "${EXISTING_MAPPER}" ] && [ "${EXISTING_MAPPER}" != "null" ]; then
  echo "Protocol mapper already exists. Skipping creation."
else
  echo "Creating protocol mapper for realm roles in ID token..."
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${INTERNAL_CLIENT_ID}/protocol-mappers/models" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "realm-roles-mapper",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-realm-role-mapper",
      "consentRequired": false,
      "config": {
        "multivalued": "true",
        "userinfo.token.claim": "true",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "realm_access.roles",
        "jsonType.label": "String"
      }
    }'

  echo "Realm roles added to ID token successfully!"
fi

echo "Generating new client secret..."
CLIENT_SECRET_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${INTERNAL_CLIENT_ID}/client-secret" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

KEYCLOAK_CLIENT_SECRET=$(echo "${CLIENT_SECRET_RESPONSE}" | jq -r .value)

echo "Generated client secret: ${KEYCLOAK_CLIENT_SECRET}"

# Save to env file
echo "KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET}" > /generated-secret


echo "Keycloak setup completed successfully!"