#!/bin/ash
REDIS_PORT=${REDIS_PORT:-6379}

REDIS_MASTER=${REDIS_MASTER:-redis}

REDIS_SENTINEL=${REDIS_SENTINEL:-sentinel}
REDIS_SENTINEL_PORT=${REDIS_SENTINEL_PORT:-26379}

MAX_ATTEMPT=${MAX_ATTEMPT:-30}
if  [[ ! -f /data/redis.conf ]]; then
  i=0
  while true; do
    # No configuration present, try to find a master from existing sentinel
    master=$(redis-cli -h ${REDIS_SENTINEL} -p ${REDIS_SENTINEL_PORT} --csv SENTINEL get-master-addr-by-name mymaster | grep -v "NIL"  | tr ',' ' ' | cut -d' ' -f1)
    if [[ -n "${master}" ]]; then
      echo "A master is found using sentinel, try to connect to it..."
      echo $master
      master="${master//\"}"
    else
      echo "No master or sentinel found, try to connect to a backup redis host..."
      role=$(redis-cli -h $REDIS_MASTER -p $REDIS_PORT INFO REPLICATIon | grep role | dos2unix)
      if [[ "role:master" == "$role" ]]; then
        echo "Redis master founded!"
        master=$REDIS_MASTER
      fi 
    fi

    if [[ -n "$master" ]]; then
    # transform hostname to IP
      master=$(getent hosts $master | cut -d' ' -f1)

      echo "Generate redis config..."
      echo "slaveof $master $REDIS_PORT"
      echo "slaveof $master $REDIS_PORT" >> /data/redis.conf
      break
    fi

    echo "No master found..."
    if [[ $i -ge $MAX_ATTEMPT ]]; then
      echo "Start as a new redis master"
      break;
    fi
    i=$(($i+1))
    sleep 1
  done
fi

redis-server /data/redis.conf --protected-mode no "$@"