 #! /bin/sh
 
 curl -X POST -H "Content-Type: application/json" -d '{"a":10}' "http://127.0.0.1:3333/webhook?session=xx&event=teste"
 