#!/bin/sh
# shellcheck disable=SC2039
# busybox supports more features that POSIX /bin/sh

set -o nounset
set -o errexit
set -o pipefail

if [ "$(id -u)" = 0 ]; then
  # set timezone using environment
  ln -snf /usr/share/zoneinfo/"${TIMEZONE:-UTC}" /etc/localtime
  # drop privileges and restart this script as foundry user
  su-exec "${FOUNDRY_UID:-foundry}:${FOUNDRY_GID:-foundry}" "$(readlink -f "$0")" "$@"
  exit 0
fi

if [ "$1" = "--version" ]; then
  cat version.txt
  exit 0
fi

if [ "$1" = "--shell" ]; then
  /bin/sh
  exit $?
fi

# Quote all strings for insertion into json
# busybox does not implement ${VAR@Q} substitution to quote variables

set +o nounset
if [[ $FOUNDRY_HOSTNAME ]]; then
  FOUNDRY_HOSTNAME=\"${FOUNDRY_HOSTNAME}\"
fi
if [[ $FOUNDRY_ROUTE_PREFIX ]]; then
  FOUNDRY_ROUTE_PREFIX=\"${FOUNDRY_ROUTE_PREFIX}\"
fi
if [[ $FOUNDRY_SSL_CERT ]]; then
  FOUNDRY_SSL_CERT=\"${FOUNDRY_SSL_CERT}\"
fi
if [[ $FOUNDRY_SSL_KEY ]]; then
  FOUNDRY_SSL_KEY=\"${FOUNDRY_SSL_KEY}\"
fi
if [[ $FOUNDRY_UPDATE_CHANNEL ]]; then
  FOUNDRY_UPDATE_CHANNEL=\"${FOUNDRY_UPDATE_CHANNEL}\"
fi
if [[ $FOUNDRY_WORLD ]]; then
  FOUNDRY_WORLD=\"${FOUNDRY_WORLD}\"
fi
set -o nounset

# Update configuration file
mkdir -p /data/Config >& /dev/null
cat <<EOF > /data/Config/options.json
{
  "port": 30000,
  "upnp": ${FOUNDRY_UPNP:-false},
  "fullscreen": false,
  "hostname": ${FOUNDRY_HOSTNAME:-null},
  "routePrefix": ${FOUNDRY_ROUTE_PREFIX:-null},
  "sslCert": ${FOUNDRY_SSL_CERT:-null},
  "sslKey": ${FOUNDRY_SSL_KEY:-null},
  "awsConfig": null,
  "dataPath": "/data",
  "proxySSL": ${FOUNDRY_PROXY_SSL:-false},
  "proxyPort": ${FOUNDRY_PROXY_PORT:-null},
  "updateChannel": ${FOUNDRY_UPDATE_CHANNEL:-\"beta\"},
  "world": ${FOUNDRY_WORLD:-null}
}
EOF

# Save admin password if it is set
if [ -n "${FOUNDRY_ADMIN_KEY}" ]; then
  echo "${FOUNDRY_ADMIN_KEY}" | ./set_password.js > /data/Config/admin.txt
else
  rm /data/Config/admin.txt >& /dev/null || true
fi

node "$@"