#!/usr/bin/env bash

usage(){
	echo "Usage: $0 [-t topic] [-w width] [-h height] [-q quality] -b [browser-command]"
  echo "       -w        Width of individual stream."
  echo "       -h        Heigth of individual stream."
  echo "       -q        Quality of the stream image."
  echo "       -t        Topic to follow - default /racecar/deepracer/kvs_stream"
  echo "       -b        Browser command (default: firefox --new-tab)"
	exit 1
}

trap ctrl_c INT

function ctrl_c() {
        echo "Requested to stop."
        exit 1
}

# Stream definition
TOPIC="/racecar/deepracer/kvs_stream"
WIDTH=480
HEIGHT=360
QUALITY=75
BROWSER="firefox --new-tab"

while getopts ":w:h:q:t:b:" opt; do
case $opt in
w) WIDTH="$OPTARG"
;;
h) HEIGHT="$OPTARG"
;;
q) QUALITY="$OPTARG"
;;
t) TOPIC="$OPTARG"
;;
b) BROWSER="$OPTARG"
;;
\?) echo "Invalid option -$OPTARG" >&2
usage
;;
esac
done

FILE=$DR_DIR/tmp/streams-$DR_RUN_ID.html
NGINX=$DR_DIR/tmp/streams-$DR_RUN_ID.conf

cat << EOF > $NGINX
server {
  listen 80;
  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
  }
EOF
echo "<html><head><title>DR-$DR_RUN_ID - $DR_LOCAL_S3_MODEL_PREFIX - $TOPIC</title></head><body><h1>DR-$DR_RUN_ID - $DR_LOCAL_S3_MODEL_PREFIX - $TOPIC</h1>" > $FILE

ROBOMAKER_CONTAINERS=$(docker ps --format "{{.ID}}" --filter name=deepracer-$DR_RUN_ID --filter "ancestor=awsdeepracercommunity/deepracer-robomaker:$DR_ROBOMAKER_IMAGE")
if [ -z "$ROBOMAKER_CONTAINERS" ]; then
    echo "No running robomakers. Exiting."
    exit
fi

for c in $ROBOMAKER_CONTAINERS; do
    C_URL="/$c/stream?topic=${TOPIC}&quality=${QUALITY}&width=${WIDTH}&height=${HEIGHT}"
    C_IMG="<img src=\"${C_URL}\"></img>"
    echo $C_IMG >> $FILE
    echo "  location /$c { proxy_pass http://$c:8080; rewrite /$c/(.*) /\$1 break; }" >> $NGINX
done

echo "</body></html>" >> $FILE
echo "}" >> $NGINX
docker rm -f deepracer-$DR_RUN_ID-viewer
docker run -d \
  -p 8081:80 \
  --network sagemaker-local \
  --name deepracer-$DR_RUN_ID-viewer \
  -v $FILE/:/usr/share/nginx/html/index.html \
  -v $NGINX:/etc/nginx/conf.d/default.conf \
  nginx
echo "Starting browser '$BROWSER'."
$BROWSER "http://127.0.01:8081" &