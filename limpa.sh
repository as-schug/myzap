#! /bin/bash


for i in tokens/*
do
   ./test.sh -s "$i"
   #echo $(basename $i)
    
done
      
      
      