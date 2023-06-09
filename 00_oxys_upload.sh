#!/bin/bash

CONFIG_FILE="oxys_tests.cfg"
REQ_UUID="$(uuidgen)"
FILE_PATH="$1"
TMP_FILE_PATH="/media/danae/public/oxys_tmpwork"
TMP_FILE_NAME="$(basename "${FILE_PATH}.gz")"
TMP_FILE="${TMP_FILE_PATH}/${TMP_FILE_NAME}"
PAYLOAD_FILE="${TMP_FILE_PATH}/payload.tmp"
# 6 MiB payload is not working, let's try with 5
MAX_FILE_SIZE="$((5*1024*1024))"


# shellcheck disable=SC1090
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

if [ -z "${FILE_PATH}" ] || [ ! -e "${FILE_PATH}" ] ; then
  echo "ERROR: Incorrect or missing file path argument." >&2
  exit 1
fi
if [ -z "${REQ_UUID}" ] ; then
  echo "ERROR: Unexpected error while generating operation UUID." >&2
  exit 1
fi

if [ ! -e "$(dirname "${TMP_FILE_PATH}")" ] ; then
  echo "ERROR: Temp dir root directory should exist" >&2
  exit 1
fi

if ! mkdir -p "${TMP_FILE_PATH}" ; then
  echo "ERROR: Unexpected error while creating tmp workdir" >&2
  exit 1
fi

# Clean the temp dir before starting
rm -fr ${TMP_FILE_PATH:?}/*

# Compress the selected file
if ! gzip < "${FILE_PATH}" | base64 | tr -d '\n' > "${TMP_FILE}" ; then
  echo "ERROR: Unexpected error while compressing file" >&2
  exit 1
fi

# Make sure the compressed size doesn't exceed the maximum allowed file size
if [ $((($(stat -c "%s" "${TMP_FILE}")+1)/MAX_FILE_SIZE)) -ne 0 ] ; then
  # File must be chopped before being sent
  split -b${MAX_FILE_SIZE} -a3 "${TMP_FILE}" "${TMP_FILE}."
  rm -f "${TMP_FILE}"
fi

# Send all the required files
for file in "${TMP_FILE_PATH}/${TMP_FILE_NAME}"* ; do
  echo "Sending file: $file"

  OXYS_TOKEN="$(oxys_auth | jq ".token" | sed 's/\"//g')"

  if [ -z "${OXYS_TOKEN}" ] ; then
    echo "ERROR: Unexpected error while generating authorization token." >&2
    exit 1
  fi

  echo -n '{"payload": "' > "${PAYLOAD_FILE}"
  tr -d '\n' < "${file}" >> "${PAYLOAD_FILE}"
  echo '", "bridge": "'"${BRIDGE_IDENTIFIER}"'"}' >> "${PAYLOAD_FILE}"

  if ! curl \
    -H "Content-Type: application/json" \
    -H "X-Request-Id: ${REQ_UUID}" \
    -H "Authorization: ${OXYS_TOKEN}" \
    -d @"${PAYLOAD_FILE}" \
    "${URL_ENDPOINT}" ; then
    echo "ERROR: Could not send $file" >&2
    exit 1
  fi
  rm -f "${file}"
  echo
  echo "$file successfully uploaded"
done
