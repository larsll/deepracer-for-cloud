#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ -f "$DIR/current-run.env" ]]
then
    export $(grep -v '^#' current-run.env | xargs)
else
    echo "File current-run.env does not exist."
    exit 1
fi

export AZ_ACCESS_KEY_ID=$(aws --profile $AZURE_S3_PROFILE configure get aws_access_key_id | xargs)
export AZ_SECRET_ACCESS_KEY=$(aws --profile $AZURE_S3_PROFILE configure get aws_secret_access_key | xargs)
