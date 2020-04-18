#!/usr/bin/env bash

trap ctrl_c INT

function ctrl_c() {
        echo "Requested to stop."
        exit 1
}

OPT_ARCH="gpu"
OPT_CLOUD="local"

while getopts ":m:c:a:" opt; do
case $opt in
a) OPT_ARCH="$OPTARG"
;;
m) OPT_MOUNT="$OPTARG"
;; 
c) OPT_CLOUD="$OPTARG"
;;
\?) echo "Invalid option -$OPTARG" >&2
exit 1
;;
esac
done

# Find CPU Level
CPU_LEVEL="cpu"
if [[ "$(dmesg | grep AVX | wc -l)" > 0 ]]; then 
    CPU_LEVEL="cpu-avx"
fi

if [[ "$(dmesg | grep AVX2 | wc -l)" > 0 ]]; then 
    CPU_LEVEL="cpu-avx2"
fi

if [[ "$(dmesg | grep AVX-512 | wc -l)" > 0 ]]; then 
    CPU_LEVEL="cpu-avx512"
fi

# Check if Intel (to ensure MKN)
if [[ "$(dmesg | grep GenuineIntel | wc -l)" > 0 ]]; then 
    CPU_INTEL="true"
fi

# Check GPU
if [[ "${OPT_ARCH}" == "gpu" ]]
then
    GPUS=$(docker run --rm --gpus all nvidia/cuda:10.2-base nvidia-smi "-L" 2> /dev/null | awk  '/GPU .:/' | wc -l )
    if [ $? -ne 0 ] || [ $GPUS -eq 0 ]
    then
        echo "No GPU detected in docker. Using CPU".
        OPT_ARCH="cpu"
    fi
fi


INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
cd $INSTALL_DIR

# create directory structure for docker volumes

if [[ -n "$OPT_MOUNT" ]];
then
    mount "${OPT_MOUNT}"
fi
sudo mkdir -p /mnt/deepracer /mnt/deepracer/recording /mnt/deepracer/robo/checkpoint /mnt/deepracer/minio/bucket
sudo chown -R $(id -u):$(id -g) /mnt/deepracer 
mkdir -p $INSTALL_DIR/docker/volumes

# create symlink to current user's home .aws directory 
# NOTE: AWS cli must be installed for this to work
# https://docs.aws.amazon.com/cli/latest/userguide/install-linux-al2017.html
mkdir -p $(eval echo "~${USER}")/.aws
ln -sf $(eval echo "~${USER}")/.aws  $INSTALL_DIR/docker/volumes/

# copy rewardfunctions
mkdir -p $INSTALL_DIR/custom_files $INSTALL_DIR/logs $INSTALL_DIR/analysis
cp $INSTALL_DIR/defaults/hyperparameters.json $INSTALL_DIR/custom_files/
cp $INSTALL_DIR/defaults/model_metadata.json $INSTALL_DIR/custom_files/
cp $INSTALL_DIR/defaults/reward_function.py $INSTALL_DIR/custom_files/

cp $INSTALL_DIR/defaults/template-system.env $INSTALL_DIR/system.env
cp $INSTALL_DIR/defaults/template-run.env $INSTALL_DIR/run.env

if [[ "${OPT_CLOUD}" == "aws" ]]; then
    AWS_DR_BUCKET=$(aws s3api list-buckets | jq '.Buckets[] | select(.Name | startswith("aws-deepracer")) | .Name' -r)
    AWS_EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    AWS_REGION="`echo \"$AWS_EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"
    if [[ !  -z "${AWS_DR_BUCKET}" ]]; then
        sed -i "s/<AWS_DR_BUCKET>/$AWS_DR_BUCKET/g" $INSTALL_DIR/system.env
    fi
else
    AWS_REGION="us-east-1"
fi

sed -i "s/<CLOUD_REPLACE>/$OPT_CLOUD/g" $INSTALL_DIR/system.env
sed -i "s/<REGION_REPLACE>/$AWS_REGION/g" $INSTALL_DIR/system.env


if [[ "${OPT_ARCH}" == "gpu" ]]; then
    SAGEMAKER_TAG="gpu"   
elif [[ -n "${CPU_INTEL}" ]]; then
    SAGEMAKER_TAG="cpu-avx-mkn" 
else
    SAGEMAKER_TAG="cpu" 
fi
sed -i "s/<SAGE_TAG>/$SAGEMAKER_TAG/g" $INSTALL_DIR/system.env
sed -i "s/<ROBO_TAG>/$CPU_LEVEL/g" $INSTALL_DIR/system.env

#set proxys if required
for arg in "$@";
do
    IFS='=' read -ra part <<< "$arg"
    if [ "${part[0]}" == "--http_proxy" ] || [ "${part[0]}" == "--https_proxy" ] || [ "${part[0]}" == "--no_proxy" ]; then
        var=${part[0]:2}=${part[1]}
        args="${args} --build-arg ${var}"
    fi
done

# Download docker images. Change to build statements if locally built images are desired.
docker pull larsll/deepracer-rlcoach:v2
docker pull awsdeepracercommunity/deepracer-robomaker:$CPU_LEVEL
docker pull awsdeepracercommunity/deepracer-sagemaker:$SAGEMAKER_TAG
docker pull larsll/deepracer-loganalysis:v2-cpu

# create the network sagemaker-local if it doesn't exit
SAGEMAKER_NW='sagemaker-local'
docker network ls | grep -q $SAGEMAKER_NW
if [ $? -ne 0 ]
then
	  docker network create $SAGEMAKER_NW
fi

# ensure our variables are set on startup
echo "source $INSTALL_DIR/bin/activate.sh" >> $HOME/.profile

# mark as done
date | tee $INSTALL_DIR/DONE
