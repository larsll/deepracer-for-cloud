#!/usr/bin/env bash

source $DR_DIR/bin/scripts_wrapper.sh

usage(){
	echo "Usage: $0 [-w] [-q | -s | -r [n] | -a ]"
  echo "       -w        Wipes the target AWS DeepRacer model structure before upload."
  echo "       -q        Do not output / follow a log when starting."
  echo "       -a        Follow all Sagemaker and Robomaker logs."
  echo "       -s        Follow Sagemaker logs (default)."
  echo "       -r [n]    Follow Robomaker logs for worker n (default worker 0 / replica 1)."
	exit 1
}

trap ctrl_c INT

function ctrl_c() {
        echo "Requested to stop."
        exit 1
}

OPT_DISPLAY="SAGEMAKER"

while getopts ":whqsar:" opt; do
case $opt in
w) OPT_WIPE="WIPE"
;;
q) OPT_QUIET="QUIET"
;;
s) OPT_DISPLAY="SAGEMAKER"
;;
a) OPT_DISPLAY="ALL"
;;
r)  # Check if value is in numeric format.
    OPT_DISPLAY="ROBOMAKER"
    if [[ $OPTARG =~ ^[0-9]+$ ]]; then
        OPT_ROBOMAKER=$OPTARG
    else
        OPT_ROBOMAKER=0
        ((OPTIND--))
    fi
;;  
h) usage
;;
\?) echo "Invalid option -$OPTARG" >&2
usage
;;
esac
done

# Ensure Sagemaker's folder is there
if [ ! -d /tmp/sagemaker ]; then
  sudo mkdir -p /tmp/sagemaker
fi

#Check if files are available
S3_PATH="s3://$DR_LOCAL_S3_BUCKET/$DR_LOCAL_S3_MODEL_PREFIX"

S3_FILES=$(aws ${DR_LOCAL_PROFILE_ENDPOINT_URL} s3 ls ${S3_PATH} | wc -l)
if [[ $S3_FILES > 0 ]];
then  
  if [[ -z $OPT_WIPE ]];
  then
    echo "Selected path $S3_PATH exists. Delete it, or use -w option. Exiting."
    exit 1
  else
    echo "Wiping path $S3_PATH."
    aws ${DR_LOCAL_PROFILE_ENDPOINT_URL} s3 rm --recursive ${S3_PATH}
  fi
fi

# Base compose file
if [ ${DR_ROBOMAKER_MOUNT_LOGS,,} = "true" ];
then
  COMPOSE_FILES="$DR_TRAIN_COMPOSE_FILE $DR_DOCKER_FILE_SEP $DR_DIR/docker/docker-compose-mount.yml"
  export DR_MOUNT_DIR="$DR_DIR/data/logs/robomaker/$DR_LOCAL_S3_MODEL_PREFIX"
  mkdir -p $DR_MOUNT_DIR
else
  COMPOSE_FILES="$DR_TRAIN_COMPOSE_FILE"
fi

# set evaluation specific environment variables
STACK_NAME="deepracer-$DR_RUN_ID"

export DR_CURRENT_PARAMS_FILE=${DR_LOCAL_S3_TRAINING_PARAMS_FILE}

echo "Creating Robomaker configuration in $S3_PATH/$DR_LOCAL_S3_TRAINING_PARAMS_FILE"
python3 prepare-config.py

if [ "$DR_WORKERS" -gt 1 ]; then
  echo "Starting $DR_WORKERS workers"

  if [[ "${DR_DOCKER_STYLE,,}" != "swarm" ]];
  then
    mkdir -p $DR_DIR/tmp/comms.$DR_RUN_ID
    rm -rf $DR_DIR/tmp/comms.$DR_RUN_ID/*
    COMPOSE_FILES="$COMPOSE_FILES $DR_DOCKER_FILE_SEP $DR_DIR/docker/docker-compose-robomaker-multi.yml"
  fi

  if [ "$DR_TRAIN_MULTI_CONFIG" == "True" ]; then
    echo "Multi-config training"

    i=1
    while [[ $i -le $DR_WORKERS ]] 
    do
        YAML_ARRAY[$i]=$(echo ${DR_LOCAL_S3_TRAINING_PARAMS_FILE} | sed s/.yaml/_$i.yaml/)
        declare "MT_S3_TRAINING_PARAMS_FILE_$i=${YAML_ARRAY[$i]}"
        ((i = i + 1))
    done

    export MT_S3_TRAINING_PARAMS_FILE_1=$MT_S3_TRAINING_PARAMS_FILE_1
    export MT_S3_TRAINING_PARAMS_FILE_2=$MT_S3_TRAINING_PARAMS_FILE_2
    export MT_S3_TRAINING_PARAMS_FILE_3=$MT_S3_TRAINING_PARAMS_FILE_3
    export MT_S3_TRAINING_PARAMS_FILE_4=$MT_S3_TRAINING_PARAMS_FILE_4
    export MT_S3_TRAINING_PARAMS_FILE_5=$MT_S3_TRAINING_PARAMS_FILE_5
    export MT_S3_TRAINING_PARAMS_FILE_6=$MT_S3_TRAINING_PARAMS_FILE_6
    export MT_S3_TRAINING_PARAMS_FILE_7=$MT_S3_TRAINING_PARAMS_FILE_7
    export MT_S3_TRAINING_PARAMS_FILE_8=$MT_S3_TRAINING_PARAMS_FILE_8

    # read in multiconfig.txt file, and export the world file
    source $DR_DIR/tmp/$DR_RUN_ID-multiconfig.txt

    # this command tells the robomaker worker which world_name and params_file to use
    export ROBOMAKER_COMMAND='if [[ "$DOCKER_REPLICA_SLOT" == *"1"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_1; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_1; elif [[ "$DOCKER_REPLICA_SLOT" == *"2"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_2; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_2; elif [[ "$DOCKER_REPLICA_SLOT" == *"3"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_3; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_3; elif [[ "$DOCKER_REPLICA_SLOT" == *"4"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_4; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_4; elif [[ "$DOCKER_REPLICA_SLOT" == *"5"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_5; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_5; elif [[ "$DOCKER_REPLICA_SLOT" == *"6"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_6; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_6; elif [[ "$DOCKER_REPLICA_SLOT" == *"7"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_7; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_7; elif [[ "$DOCKER_REPLICA_SLOT" == *"8"* ]]; then export WORLD_NAME=$DR_MT_WORLD_NAME_8; export S3_YAML_NAME=$MT_S3_TRAINING_PARAMS_FILE_8; fi && ./run.sh multi distributed_training.launch'
  COMPOSE_FILES="$COMPOSE_FILES $DR_DOCKER_FILE_SEP $DR_DIR/docker/docker-compose-multiconfig.yml"
  else   # not multi config training
    export ROBOMAKER_COMMAND="./run.sh multi distributed_training.launch"
  fi
else
  export ROBOMAKER_COMMAND="./run.sh run distributed_training.launch"
fi

# Check if we will use Docker Swarm or Docker Compose
if [[ "${DR_DOCKER_STYLE,,}" == "swarm" ]];
then
  docker stack deploy $COMPOSE_FILES $STACK_NAME
else
  docker-compose $COMPOSE_FILES -p $STACK_NAME --log-level ERROR up -d --scale robomaker=$DR_WORKERS
fi

# Request to be quiet. Quitting here.
if [ -n "$OPT_QUIET" ]; then
  exit 0
fi

# Trigger requested log-file
if [[ "${OPT_DISPLAY,,}" == "all" && -n "${DISPLAY}" && "${DR_HOST_X,,}" == "true" ]]; then
  dr-logs-sagemaker -w 15
  if [ "${DR_WORKERS}" -gt 1 ]; then
    for i in $(seq 1 ${DR_WORKERS})
    do
      dr-logs-robomaker -w 15 -n $i
    done    
  else
    dr-logs-robomaker -w 15
  fi
elif [[ "${OPT_DISPLAY,,}" == "robomaker" ]]; then
  dr-logs-robomaker -w 15 -n $OPT_ROBOMAKER
elif [[ "${OPT_DISPLAY,,}" == "sagemaker" ]]; then
  dr-logs-sagemaker -w 15
fi

