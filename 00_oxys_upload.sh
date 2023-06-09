#!/bin/bash

CONFIG_FILE="oxys_tests.cfg"
REQ_UUID="$(uuidgen)"
FILE_PATH="$1"
TMP_FILE_PATH="oxys_file.tmp"

. "${CONFIG_FILE}"

oxys_auth() {
  curl -s -S --location "${AUTH_URL}" \
    --header 'Content-Type: application/json' \
    --header 'X-Request-Id: "'"${REQ_UUID}"'"' \
    --data '{
        "key": "'"${AUTH_KEY}"'",
        "scope": "'"${AUTH_SCOPE}"'"
    }'
}

if [ -z $FILE_PATH ] || [ ! -e "${FILE_PATH}" ] ; then
  echo "ERROR: Incorrect or missing file path argument." >&2
  exit 1
fi
if [ -z $REQ_UUID ] ; then
  echo "ERROR: Unexpected error while generating operation UUID." >&2
  exit 1
fi

OXYS_TOKEN="$(oxys_auth | jq ".token" | sed 's/\"//g')"

if [ -z $OXYS_TOKEN ] ; then
  echo "ERROR: Unexpected error while generating authorization token." >&2
  exit 1
fi


if [ -z $TMPFILE_METHOD ] ; then
  echo "ORG: Before upload"
  cat "${FILE_PATH}" | gzip -c | base64 | curl -X POST \
    -H "Content-Type: application/json" \
    -H "X-Request-Id: ${REQ_UUID}" \
    -H "Authorization: ${OXYS_TOKEN}" \
    -d '{"payload": "'"$(</dev/stdin)"'", "bridge": "'"${BRIDGE_IDENTIFIER}"'"}' \
    "${URL_ENDPOINT}"
  echo
  echo "ORG: After upload"
else
  echo -n '{"payload": "' > "${TMP_FILE_PATH}"
 cat "${FILE_PATH}" | gzip -c | base64 | tr -d '\n' >> "${TMP_FILE_PATH}"
  echo '", "bridge": "'"${BRIDGE_IDENTIFIER}"'"}' >> "${TMP_FILE_PATH}"

  echo "TMPFILE: Before upload"
  curl \
    -H "Content-Type: application/json" \
    -H "X-Request-Id: ${REQ_UUID}" \
    -H "Authorization: ${OXYS_TOKEN}" \
    -d @"${TMP_FILE_PATH}" \
    "${URL_ENDPOINT}"
  echo
  echo "TMPFILE: After upload"
fi
