#! /bin/bash


#docker build  -t myzap .

docker start myzap || \
   docker run -d --name myzap -p 3334:3333 -p 3333:3333 -v /mnt/hdd/tokens:/usr/src/app/tokens myzap

#watch "ps -efww|grep pidof -s node"
#ps -efw|grep user-data-dir

