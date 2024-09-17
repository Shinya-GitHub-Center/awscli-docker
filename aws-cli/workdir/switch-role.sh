#!/bin/bash

# Load variables
source ./vars-switchrole.txt

# Get authentication credentials
AWS_STS_CREDENTIALS=$(aws sts assume-role \
  --role-arn arn:aws:iam::"${TARGET_ACCTID}":role/"${ROLE_NAME}" \
  --role-session-name "${SESSION_NAME}")

# Extract credentials
AWS_ACCESS_KEY_ID=$(echo "${AWS_STS_CREDENTIALS}" | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "${AWS_STS_CREDENTIALS}" | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "${AWS_STS_CREDENTIALS}" | jq -r '.Credentials.SessionToken')

# Set environment variables
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

echo "Switched role successfully."
