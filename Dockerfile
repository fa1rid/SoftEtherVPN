FROM alpine:3.17 as prep

ENV BUILD_VERSION=4.41-9782-beta

RUN wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/archive/v${BUILD_VERSION}.tar.gz \
    && mkdir -p /usr/local/src \
    && tar -x -C /usr/local/src/ -f v${BUILD_VERSION}.tar.gz \
    && rm v${BUILD_VERSION}.tar.gz

FROM alpine:3.16 as build

COPY --from=prep /usr/local/src /usr/local/src

ENV LANG=en_US.UTF-8

RUN apk add -U build-base ncurses-dev openssl-dev readline-dev zip zlib-dev \
    && cd /usr/local/src/SoftEtherVPN_Stable-* \
    && ./configure \
    && make \
    && make install \
    && touch /usr/vpnserver/vpn_server.config \
    && zip -r9 /artifacts.zip /usr/vpn* /usr/bin/vpn*

FROM alpine:3.17

COPY --from=build /artifacts.zip /

COPY copyables /

ENV LANG=en_US.UTF-8

RUN apk add -U --no-cache bash iptables openssl-dev \
    && chmod +x /entrypoint.sh /gencert.sh \
    && unzip -o /artifacts.zip -d / \
    && rm /artifacts.zip \
    && rm -rf /opt \
    && ln -s /usr/vpnserver /opt \
    && find /usr/bin/vpn* -type f ! -name vpnserver \
       -exec sh -c 'ln -s {} /opt/$(basename {})' \;

WORKDIR /usr/vpnserver/

VOLUME ["/usr/vpnserver/server_log/", "/usr/vpnserver/packet_log/", "/usr/vpnserver/security_log/"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 500/udp 4500/udp 1701/tcp 1194/udp 5555/tcp 443/tcp

CMD ["/usr/bin/vpnserver", "execsvc"]
