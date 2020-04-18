#!/usr/bin/env bash

export STACK_NAME="deepracer-$DR_RUN_ID"
docker stack rm $STACK_NAME

SAGEMAKER=$(docker ps | awk ' /sagemaker/ { print $1 }')
if [[ -n $SAGEMAKER ]];
then
    docker stop $(docker ps | awk ' /sagemaker/ { print $1 }')
    docker rm $(docker ps -a | awk ' /sagemaker/ { print $1 }')
fi