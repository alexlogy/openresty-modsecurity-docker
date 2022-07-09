FROM debian:buster-slim AS BUILDER

LABEL author="alex@alexlogy.io"
LABEL description="Openresty w ModSecurity"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates openssl g++ flex bison doxygen libyajl-dev libgeoip-dev libtool \
        dh-autoreconf libxml2 libpcre++-dev libxml2-dev libcurl4-openssl-dev \
        openssl git libssl-dev libpcre3 libpcre3-dev zlib1g zlib1g-dev wget \
    && git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity/ \
    && cd /usr/local/src/ModSecurity/ \
    && git submodule init \ 
    && git submodule update \
    && ./build.sh \
    && ./configure \
    && make \
    && make install \
    && git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx/ \
    && wget https://openresty.org/download/openresty-1.21.4.1.tar.gz -P /usr/local/src/ \
    && cd /usr/local/src/ \
    && tar zxvf openresty-1.21.4.1.tar.gz \
    && cd openresty-1.21.4.1 \
    && ./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx --with-http_stub_status_module \
        --with-http_realip_module --with-http_addition_module --with-http_auth_request_module \
        --with-http_secure_link_module --with-http_random_index_module --with-http_gzip_static_module \
        --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module \
        --with-threads --with-stream \
    && make \
    && make install

FROM debian:buster-slim AS APP

MAINTAINER devops@up-devops.io

ENV TZ="Asia/Hong_Kong"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext-base \
        gnupg2 \
        lsb-base \
        lsb-release \
        software-properties-common \
        wget curl telnet net-tools nano inetutils-ping tzdata procps \
        libgeoip1 libxml2 libyajl2 \
    && wget -qO /tmp/pubkey.gpg https://openresty.org/package/pubkey.gpg \
    && DEBIAN_FRONTEND=noninteractive apt-key add /tmp/pubkey.gpg \
    && rm /tmp/pubkey.gpg \
    && DEBIAN_FRONTEND=noninteractive add-apt-repository -y "deb http://openresty.org/package/debian $(lsb_release -sc) openresty" \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openresty-opm \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && ln -s /usr/local/openresty/nginx/conf/ /etc/nginx \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /proc/self/fd/1 /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /proc/self/fd/2 /usr/local/openresty/nginx/logs/error.log \
    && opm get timebug/lua-resty-redis-ratelimit

COPY --from=builder /usr/local/openresty/ /usr/local/openresty/
COPY --from=builder /usr/local/modsecurity/ /usr/local/modsecurity/

# Add additional binaries into PATH for convenience
ENV PATH="$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin"

CMD ["/usr/bin/openresty", "-g", "daemon off;"]

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
# See https://github.com/openresty/docker-openresty/blob/master/README.md#tips--pitfalls
STOPSIGNAL SIGQUIT
