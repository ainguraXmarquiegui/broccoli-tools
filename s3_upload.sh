#!/bin/bash

# Set your AWS access key ID and secret access key
AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"

# Set the S3 bucket name
BRIDGE_IDENTIFIER="bridge-identifier"

# Set the AWS region
REGION="us-east-1"

# Generate the timestamp in the required format
DATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")

# Set the local path to the file you want to upload
LOCAL_FILE="/path/to/your-file.gz"

# Extract the year and month from the current date
YEAR=$(date -u +"%Y")
MONTH=$(date -u +"%m")

# Set the object key dynamically
OBJECT_KEY="${YEAR}/${MONTH}/${DATE}.gz"

# Generate the signature for the request
SIGNATURE=$(printf "PUT\n\napplication/x-gzip\n${DATE}\nx-amz-acl:private\n/${BRIDGE_IDENTIFIER}/${OBJECT_KEY}" | \
  openssl sha1 -binary -hmac "${AWS_SECRET_ACCESS_KEY}" | base64)

# Perform the file upload to S3 using cURL
curl -X PUT -T "${LOCAL_FILE}" \
  -H "Host: ${BRIDGE_IDENTIFIER}.s3.amazonaws.com" \
  -H "Date: ${DATE}" \
  -H "Content-Type: application/x-gzip" \
  -H "x-amz-acl: private" \
  -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${SIGNATURE}" \
  "https://${BRIDGE_IDENTIFIER}.s3.${REGION}.amazonaws.com/${OBJECT_KEY}"