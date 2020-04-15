FROM redis:5.0.8-alpine
COPY entrypoint_redis.sh /entrypoint_redis.sh
COPY redis.conf /opt/redis/redis.conf.template
ENTRYPOINT ["/entrypoint_redis.sh"]