FROM alpine:3.18

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories

# apk upgrade in a separate layer (musl is huge)
RUN apk upgrade --no-cache --update

# Bring in tzdata and runtime libs into their own layer
RUN apk add --no-cache --update tzdata pcre zlib libssl1.1

ENV LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_INC=/usr/local/include/luajit-2.1

ARG NGINX_VERSION="1.25.3"
ARG HTTPS_PROXY
ARG LUA_VERSION="0.10.26"
ARG LUAJIT2_VERSION="2.1-20240314"
ARG LUA_RESTY_CORE_VERSION="0.1.28"
ARG LUA_RESTY_LRUCACHE_VERSION="0.13"
# nginx layer
RUN CONFIG="\
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-http_slice_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module \
        " \
        && addgroup -S nginx \
        && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
        && apk add --no-cache --update --virtual .build-deps gcc libc-dev make openssl-dev pcre-dev zlib-dev linux-headers patch curl git  \
        && curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
        && curl -fSL https://github.com/openresty/lua-nginx-module/archive/refs/tags/v${LUA_VERSION}.tar.gz -o lua.tar.gz \
        && curl -fSL https://github.com/openresty/luajit2/archive/refs/tags/v${LUAJIT2_VERSION}.tar.gz -o luajit2.tar.gz \
        && curl -fSL https://github.com/openresty/lua-resty-core/archive/refs/tags/v${LUA_RESTY_CORE_VERSION}.tar.gz -o lua_resty_core.tar.gz \
        && curl -fSL https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz -o lua-resty-lrucache.tar.gz \
        && git clone https://github.com/openresty/lua-upstream-nginx-module.git /usr/src/lua-upstream-nginx-module \
        && git clone https://github.com/ledgetech/lua-resty-http.git /usr/src/lua-resty-http \
        && git clone https://github.com/openresty/lua-resty-string.git /usr/src/lua-resty-string \
        && git clone https://github.com/fffonion/lua-resty-openssl.git /usr/src/lua-resty-openssl \
        && CONFIG="$CONFIG --add-module=/usr/src/lua-upstream-nginx-module --add-module=/usr/src/lua-nginx-module-${LUA_VERSION}" \
        && mkdir -p /usr/src \
        && tar -zxC /usr/src -f nginx.tar.gz \
        && tar -zxC /usr/src -f lua.tar.gz \
        && tar -zxC /usr/src -f luajit2.tar.gz \
        && tar -zxC /usr/src -f lua_resty_core.tar.gz \
        && tar -zxC /usr/src -f lua-resty-lrucache.tar.gz \
        && rm nginx.tar.gz && rm lua.tar.gz && rm lua-resty-lrucache.tar.gz && rm luajit2.tar.gz  && rm lua_resty_core.tar.gz \
        && cd /usr/src/luajit2-${LUAJIT2_VERSION} && make && make install \
        && cd /usr/src/lua-resty-core-${LUA_RESTY_CORE_VERSION} && make install \
        && cd /usr/src/lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION}  && make install \
        && cd /usr/src/lua-resty-http  && make install \
        && cd /usr/src/lua-resty-string  && make install \
        && cd /usr/src/lua-resty-openssl  && make install \
        && cd /usr/src/nginx-$NGINX_VERSION \
        && { echo "Bulding RELEASE" && ./configure $CONFIG  && make -j$(getconf _NPROCESSORS_ONLN) && make install; } \
        && rm -rf /etc/nginx/html/ \
        && mkdir /etc/nginx/conf.d/ \
        && mkdir -p /usr/share/nginx/html/ \
        && install -m644 html/index.html /usr/share/nginx/html/ \
        && install -m644 html/50x.html /usr/share/nginx/html/ \
        && mkdir -p /usr/lib/nginx/modules \
        && ln -s /usr/lib/nginx/modules /etc/nginx/modules && ln -s /usr/local/lib/lua/0.10.26/resty /usr/local/share/lua/5.1/resty && ln -s /usr/local/lib/lua/0.10.26/ngx /usr/local/share/lua/5.1/ngx \
        && strip /usr/sbin/nginx* \
        && rm -rf /usr/src/nginx-$NGINX_VERSION \
        \
        # Remove -dev apks and sources
        && apk del .build-deps gcc libc-dev make openssl-dev pcre-dev zlib-dev linux-headers patch curl git && rm -rf /usr/src \
        && apk add --no-cache --update  gcc \
        \
        # forward request and error logs to docker log collector
        && ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log

#RUN ls -laR /usr/share/nginx /etc/nginx /etc/nginx/modules/ /usr/lib/nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf

# Basic sanity testing.
RUN nginx -V 2>&1 && nginx -t && ldd /usr/sbin/nginx && apk list && rm -rf /run/nginx.pid /var/cache/nginx/*_temp

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
