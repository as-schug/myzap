#! /bin/bash


chmod 777 webhook
chmod 777 webhook/*

find webhook -type f -ctime +10 -exec chmod 666 {} \; -print
find webhook -empty -delete -ctime +10 -print 


while [  true  ]
do
  echo Starting...
  sleep 10
  chmod 777 tokens
  npm start
done
      
      