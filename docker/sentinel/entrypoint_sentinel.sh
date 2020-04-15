#!/bin/ash
REDIS_PORT=${REDIS_PORT:-6379}

REDIS_MASTER=${REDIS_MASTER:-redis}

REDIS_SENTINEL=${REDIS_SENTINEL:-sentinel}
REDIS_SENTINEL_PORT=${REDIS_SENTINEL_PORT:-26379}

if  [[ ! -f /data/sentinel.conf ]]; then
  while true; do
    # No configuration present, try to find a master from existing sentinel
    master=$(redis-cli -h ${REDIS_SENTINEL} -p ${REDIS_SENTINEL_PORT} --csv SENTINEL get-master-addr-by-name mymaster | tr ',' ' ' | cut -d' ' -f1)
    if [[ -n "${master}" ]]; then
      echo "A master is found using a sentinel, try to connect to it..."
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

      echo "Generate sentinel config..."
      echo "dir /data" > /data/sentinel.conf
      echo "sentinel monitor mymaster $master $REDIS_PORT 2" >> /data/sentinel.conf
      echo "sentinel down-after-milliseconds mymaster 60000" >> /data/sentinel.conf
      echo "sentinel failover-timeout mymaster 180000" >> /data/sentinel.conf
      echo "sentinel parallel-syncs mymaster 1" >> /data/sentinel.conf
      echo "bind 0.0.0.0" >> /data/sentinel.conf
      break
    fi

    echo "No master found..."
    sleep 10
  done
fi

redis-sentinel /data/sentinel.conf --protected-mode no "$@"