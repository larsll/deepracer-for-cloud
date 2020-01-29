#!/bin/bash
#set -x

usage(){
	echo "Usage: $0 [-h] [-s <model-prefix>]"
    echo "       -s model  Configures environment to upload into selected model."
	exit 1
}

while getopts ":h:s:" opt; do
case $opt in
s) OPT_SET="$OPTARG"
;;
h) usage
;;
\?) echo "Invalid option -$OPTARG" >&2
usage
;;
esac
done

TARGET_S3_BUCKET=${UPLOAD_S3_BUCKET}
WORK_DIR=/mnt/deepracer/tmp-list
mkdir -p ${WORK_DIR} 

PARAM_FILES=$(aws s3 ls s3://${TARGET_S3_BUCKET} --recursive | awk '/training_params*/ {print $4}' )

if [[ -z "${PARAM_FILES}" ]];
then
    No models found in s3://{TARGET_S3_BUCKET}. Exiting.
    exit 1
fi

if [[ -z "${OPT_SET}" ]];
then 
    echo   -e "\nLooking for DeepRacer models in s3://${TARGET_S3_BUCKET}...\n"
    echo   "+---------------------------------------------------------------------------+"
    printf "| %-40s | %-30s |\n" "Model Name" "Creation Time"
    echo   "+---------------------------------------------------------------------------+"

    for PARAM_FILE in $PARAM_FILES; do
        aws s3 sync s3://${TARGET_S3_BUCKET}/${PARAM_FILE} ${WORK_DIR}/ --no-progress 
        PARAM_FILE_L=$(echo "$PARAM_FILE" | awk '{split($0,a,"/"); print a[2]}')
        MODIFICATION_TIME=$(stat -c %Y ${WORK_DIR}/${PARAM_FILE_L})
        MODIFICATION_TIME_STR=$(echo "@${MODIFICATION_TIME}" | xargs date -d )
        MODEL_NAME=$(awk '/MODEL_METADATA_FILE_S3_KEY/ {print $2}' ${WORK_DIR}/${PARAM_FILE_L} | awk '{split($0,a,"/"); print a[2] }')
        printf "| %-40s | %-30s |\n" "$MODEL_NAME" "$MODIFICATION_TIME_STR"
    done

    echo   "+---------------------------------------------------------------------------+"
    echo -e "\nSet the model with dr-set-upload-model <model-name>\n".
else
    echo   -e "\nLooking for DeepRacer model ${OPT_SET} in s3://${TARGET_S3_BUCKET}..."

    for PARAM_FILE in $PARAM_FILES; do
        aws s3 sync s3://${TARGET_S3_BUCKET}/${PARAM_FILE} ${WORK_DIR}/ --no-progress 
        PARAM_FILE_L=$(echo "$PARAM_FILE" | awk '{split($0,a,"/"); print a[2]}')
        MODEL_NAME=$(awk '/MODEL_METADATA_FILE_S3_KEY/ {print $2}' ${WORK_DIR}/${PARAM_FILE_L} | awk '{split($0,a,"/"); print a[2] }')
        if [ "${MODEL_NAME}" = "${OPT_SET}" ]; then
            MATCHED_PREFIX=$(echo "$PARAM_FILE" | awk '{split($0,a,"/"); print a[1]}')
            echo "Found in ${MODEL_NAME} in ${MATCHED_PREFIX}".
            break
        fi
    done
fi