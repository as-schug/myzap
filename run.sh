#! /bin/bash


#docker build  -t myzap .

#docker run --name myzap -p 3333:3333 myzap
docker start myzap || \
   docker run -d --name myzap -p 3334:3333 -p 3333:3333 -v /mnt/hdd/tokens:/usr/src/app/tokens myzap
#docker run --name myzap -v /mnt/hdd/tokens:/usr/src/app/tokens  -p 3334:3333 -p 3333:3333 --rm  myzap
docker start myzap


