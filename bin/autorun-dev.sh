#!/usr/bin/env bash

## this is the default autorun script
## file should run automatically after init.sh completes.  
## this script downloads your configured run.env, system.env and any custom container requests

## retrieve the bucket name you sent the instance earlier
BUCKET=$(cat /home/ubuntu/deepracer-for-cloud/bucket.txt)


SCRIPT_DIR_TEMP="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
INSTALL_DIR_TEMP="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

source $INSTALL_DIR/bin/scripts_wrapper.sh
source $INSTALL_DIR/bin/activate.sh


## get the updatated run.env and system.env files you created and stashed in s3
aws s3 cp s3://$BUCKET/run.env /home/ubuntu/deepracer-for-cloud/run.env
aws s3 cp s3://$BUCKET/system.env /home/ubuntu/deepracer-for-cloud/system.env


## get the right docker containers, if needed
SYSENV="/home/ubuntu/deepracer-for-cloud/system.env"
SAGEMAKER_IMAGE=$(cat $SYSENV | grep DR_SAGEMAKER_IMAGE | sed 's/.*=//')
ROBOMAKER_IMAGE=$(cat $SYSENV | grep DR_ROBOMAKER_IMAGE | sed 's/.*=//')

docker pull awsdeepracercommunity/deepracer-sagemaker:$SAGEMAKER_IMAGE
docker pull awsdeepracercommunity/deepracer-robomaker:$ROBOMAKER_IMAGE

dr-update

date | tee $INSTALL_DIR/DONE-2

## start training -- commented out for now until I can figure out how to do it properly
##cd /home/ubuntu/deepracer-for-cloud/scripts/training 
##./start.sh




