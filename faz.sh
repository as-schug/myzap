#! /bin/bash


chmod 777 webhook
chmod 777 webhook/*

while [  true  ]
do
  echo Starting...
  sleep 10
  chmod 777 tokens
  npm start
done
      
      