FROM openresty/openresty:alpine-fat AS luarocks-builder

RUN apk add --no-cache --virtual .build-deps git yaml yaml-dev \
 && luarocks install lyaml \
 && luarocks install lua-resty-prometheus \
 && apk del .build-deps

FROM igorbarinov/openresty-nginx-module-vts

COPY --from=luarocks-builder /usr/local/openresty/luajit /usr/local/openresty/luajit

RUN apk add --no-cache ca-certificates curl bash yaml \
 && update-ca-certificates \
 && addgroup -S -g 1000 user && adduser -S -u 1000 -G user user

RUN mkdir -p /etc/gwconf /tmp/nginx_cache

WORKDIR /usr/local/openresty/nginx
COPY nginx.conf conf/nginx.conf
COPY lua conf/lua

RUN chown -R user:user /usr/local/openresty/nginx /tmp/nginx_cache

USER user

EXPOSE 8080
CMD ["openresty", "-g", "daemon off;"]