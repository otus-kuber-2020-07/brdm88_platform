FROM nginx:1.19.2-alpine

RUN apk add --no-cache shadow && \
    usermod -u 1001 nginx && groupmod -g 1001 nginx && \
    chown -R nginx /var/cache/nginx && \
    mkdir /app

COPY ./conf/nginx.conf /etc/nginx/nginx.conf

USER 1001
EXPOSE 8080
