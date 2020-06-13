#!/usr/bin/env bash

## this is the default autorun script
## file should run automatically after init.sh completes.  
## this script downloads your configured run.env, system.env and any custom container requests

INSTALL_DIR_TEMP="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

## retrieve the s3_location name you sent the instance in user data launch
S3_LOCATION=$(cat $INSTALL_DIR_TEMP/tmp/s3_training_location.txt)

## get the updatated run.env and system.env files you created and stashed in s3
aws s3 cp s3://$S3_LOCATION/run.env $INSTALL_DIR_TEMP/run.env
aws s3 cp s3://$S3_LOCATION/system.env $INSTALL_DIR_TEMP/system.env

## get the right docker containers, if needed
SYSENV="$INSTALL_DIR_TEMP/system.env"
SAGEMAKER_IMAGE=$(cat $SYSENV | grep DR_SAGEMAKER_IMAGE | sed 's/.*=//')
ROBOMAKER_IMAGE=$(cat $SYSENV | grep DR_ROBOMAKER_IMAGE | sed 's/.*=//')

docker pull awsdeepracercommunity/deepracer-sagemaker:$SAGEMAKER_IMAGE
docker pull awsdeepracercommunity/deepracer-robomaker:$ROBOMAKER_IMAGE

dr-reload

date | tee $INSTALL_DIR_TEMP/DONE-AUTORUN

## start training
cd $INSTALL_DIR_TEMP/scripts/training 
nohup ./start.sh &

