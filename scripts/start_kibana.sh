#!/bin/bash

set -e
set -o pipefail

KIBANA_HOME="/usr/share/kibana"
BIN_DIR="${KIBANA_HOME}/bin"
CONFIG_DIR="${KIBANA_HOME}/config"
KIBANA_YML="${CONFIG_DIR}/kibana.yml"
KEYSTORE_SECRETS_DIR="/secrets/keystore"

add_to_keystore() {
  key="${1}"
  val="${2}"
  if [ -z "${key}" ] || [ -z "${val}" ]; then
    echo "Empty values sent to add_to_keystore [key=${key}, val=REDACTED]"
    return
  else
    echo "${val}" | "${BIN_DIR}/kibana-keystore" add "${key}" --stdin
    "${BIN_DIR}/kibana-keystore" list "${key}" >/dev/null 2>&1
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "There was an error adding ${key} to keystore"
      exit 1
    fi
  fi
}

# copy any injected config files to correct directory
if [ -d "${CONFIG_DIR}/injected" ]; then
    cp -vb ${CONFIG_DIR}/injected/* ${CONFIG_DIR}
fi

# enable/disable security based on environment vars (can't specify var directly in yaml)
# as kibana incorrectly treats it as a string and fails startup validation
sed -ie "s/server.ssl.enabled:.*/server.ssl.enabled: ${SECURE}/" ${KIBANA_YML}
sed -ie "s/xpack.security.enabled:.*/xpack.security.enabled: ${SECURE}/" ${KIBANA_YML}
sed -ie "s/xpack.security.audit.enabled:.*/xpack.security.audit.enabled: ${SECURE}/" ${KIBANA_YML}
sed -ie "s/elasticsearch.ssl.alwaysPresentCertificate:.*/elasticsearch.ssl.alwaysPresentCertificate: ${SECURE}/" ${KIBANA_YML}

if [ "${SECURE_PROXY,,}" = "true" ]; then
  sed -ie "s/xpack.security.secureCookies:.*/xpack.security.secureCookies: ${SECURE_PROXY}/" ${KIBANA_YML}
fi

# Create keystore
"${BIN_DIR}/kibana-keystore" create

if [ -d "${KEYSTORE_SECRETS_DIR}" ]; then
  while IFS= read -r -d '' secret; do
    key=$(basename "${secret}")
    val=$(head -1 "${secret}")

    echo "Add keystore entry for ${key}"
    add_to_keystore "${key}" "${val}"
  done < <(find "${KEYSTORE_SECRETS_DIR}" -type f -print0)
fi

# start kibana
/usr/local/bin/kibana-docker
