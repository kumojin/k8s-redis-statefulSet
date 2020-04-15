#!/bin/ash
REDIS_PORT=${REDIS_PORT:-6379}

REDIS_MASTER=${REDIS_MASTER:-redis}

REDIS_SENTINEL_SERVICE_HOST=${REDIS_SENTINEL_SERVICE_HOST:-sentinel}
REDIS_SENTINEL_SERVICE_PORT=${REDIS_SENTINEL_SERVICE_PORT:-26379}

MAX_ATTEMPT=${MAX_ATTEMPT:-10}

cp /opt/redis/redis.conf.template /tmp/redis.conf
i=0
while true; do
  # No configuration present, try to find a master from existing sentinel
  master=$(timeout 1 redis-cli -h ${REDIS_SENTINEL_SERVICE_HOST} -p ${REDIS_SENTINEL_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name mymaster | grep -v "NIL"  | tr ',' ' ' | cut -d' ' -f1)
  if [[ -n "${master}" ]]; then
    echo "A master is found using sentinel, try to connect to it..."
    echo $master
    master="${master//\"}"
    redis cli -h $master -p $REDIS_PORT PING
    if [[ $? -ne 0 ]]; then
      echo "$master didn't respond to PING request..."
      master=""
    fi
  fi

  if [[ -n "$master" ]]; then
  # transform hostname to IP
    master=$(getent hosts $master | cut -d' ' -f1)

    echo "Redis master founded!"
    echo "slaveof $master $REDIS_PORT" >> /tmp/redis.conf
    break
  fi
  
  # Giveup to try with sentinel
  if [[ $i -ge $MAX_ATTEMPT ]]; then
    break;
  fi

  i=$(($i+1))
  sleep 1
done


echo "No master found using sentinel, try to connect to a backup redis host..."
role=$(timeout 1 redis-cli -h $REDIS_MASTER -p $REDIS_PORT INFO REPLICATIon | grep role | dos2unix)
if [[ "role:master" == "$role" ]]; then
  echo "Redis master founded!"
  master=$REDIS_MASTER
  master=$(getent hosts $master | cut -d' ' -f1)
  echo "slaveof $master $REDIS_PORT" >> /tmp/redis.conf
else
  echo "No master found..."
  echo "Start as a new redis master"
fi 


redis-server /tmp/redis.conf --protected-mode no "$@"