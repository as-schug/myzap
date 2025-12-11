
MODULOS="MYZAP-MAIN MYZAP-MAIN-WEB01 MYZAP-MAIN-WEB02 MYZAP-MAIN-WEB03 MYZAP-MAIN-WEB04 MYZAP-MAIN-WEB05"

for i in $MODULOS 
do
  echo "Install $i"
  docker start $i
  sleep 2
  docker exec -it $i npm install
  echo "Update $i"  
  docker exec -it $i npm update
  echo "Restart $i"
  docker stop $i 
  docker start $i
done