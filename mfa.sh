#!/bin/bash
#
# Sample for getting temp session token from AWS STS
#
# aws --profile youriamuser sts get-session-token --duration 3600 \
# --serial-number arn:aws:iam::012345678901:mfa/user --token-code 012345
#
# Once the temp token is obtained, you'll need to feed the following environment
# variables to the aws-cli:
#
# export AWS_ACCESS_KEY_ID='KEY'
# export AWS_SECRET_ACCESS_KEY='SECRET'
# export AWS_SESSION_TOKEN='TOKEN'

AWS_CLI=`which aws`

if [ $? -ne 0 ]; then
  echo "AWS CLI is not installed; exiting"
  exit 1
else
  echo "Using AWS CLI found at $AWS_CLI"
fi

# 1 or 2 args ok
if [[ $# -ne 1 && $# -ne 2 ]]; then
  echo "Usage: $0 <MFA_TOKEN_CODE> <AWS_CLI_PROFILE>"
  echo "Where:"
  echo "   <MFA_TOKEN_CODE> = Code from virtual MFA device"
  echo "   <AWS_CLI_PROFILE> = aws-cli profile usually in $HOME/.aws/config"
  exit 2
fi

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P  )"
MFA_CONFIG=$(echo "$SCRIPT_PATH/mfa.cfg")
echo "Reading config..."
if [ ! -r $MFA_CONFIG ]; then
  echo "No config found.  Please create your mfa.cfg.  See README.txt for more info."
  exit 2
fi

AWS_CLI_PROFILE=${2:-default}
MFA_TOKEN_CODE=$1
ARN_OF_MFA=$(grep "^$AWS_CLI_PROFILE=" $MFA_CONFIG | cut -d '=' -f2- | tr -d '"')

# read credentials
CREDENTIALS_FILE="$HOME/.aws/credentials"
CREDENTIALS_TMP="$HOME/.aws/credentials.tmp"
n=1
while read line; do
# reading the first three lines ()
    if [ "$n" -eq 2 ]
    then
        ID=$(echo $line | cut -d "=" -f2)
    elif [ "$n" -eq 3 ]
    then
        KEY=$(echo $line | cut -d "=" -f2)
    fi    
    n=$((n+1))
done < $CREDENTIALS_FILE

echo "AWS-CLI Profile: $AWS_CLI_PROFILE"
echo "MFA ARN: $ARN_OF_MFA"
echo "MFA Token Code: $MFA_TOKEN_CODE"

printf "Checking MFA: \n"
aws --profile $AWS_CLI_PROFILE sts get-session-token --duration 129600 \
  --serial-number $ARN_OF_MFA --token-code $MFA_TOKEN_CODE --output text \
  | awk '{printf("[default]\naws_access_key_id='"$ID"'\naws_secret_access_key='"$KEY"'\n\n[mfa]\naws_access_key_id=%s\naws_secret_access_key=%s\naws_session_token=%s\n", $2, $4, $5)}' | tee $CREDENTIALS_TMP

printf "Update %s\n" $CREDENTIALS_FILE
mv $CREDENTIALS_TMP $CREDENTIALS_FILE