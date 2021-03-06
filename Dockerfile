FROM golang:1.14-alpine3.11 as builder

RUN apk add --no-cache g++ gcc make cmake git nano libcurl python3 python3-dev \
        curl bash curl-dev linux-headers

RUN apk --no-cache add ca-certificates wget
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk
RUN apk add glibc-2.28-r0.apk

WORKDIR /root

ADD https://api.github.com/repos/Great-Hill-Corporation/trueblocks-core/git/refs/heads/develop version.json
RUN git clone -b 'develop' --single-branch --progress --depth 1 \
        https://github.com/Great-Hill-Corporation/trueblocks-core.git \
        /root/quickBlocks-src && \
        cat /root/quickBlocks-src/src/other/install/docker/post_build.sh

RUN cd /root/quickBlocks-src && \
        mkdir -v build /root/.quickBlocks && \
        cd build && \
        bash ../src/other/install/docker/clean_for_docker.sh && \
        cmake ../src && \
        make && \
        bash ../src/other/install/docker/post_build.sh

RUN git clone -b 'master' --single-branch --progress --depth 1 \
        https://github.com/TrueBlocks/trueblocks-explorer.git \
        /root/trueblocks-explorer

FROM node:12.18.4-alpine3.12
WORKDIR /root

RUN apk add --no-cache libcurl python3 python3-dev procps bash
COPY --from=builder /root/trueblocks-explorer /root/trueblocks-explorer
COPY --from=builder /root/quickBlocks-src/bin /usr/local/bin
COPY --from=builder /root/.quickBlocks /root/.quickBlocks
COPY --from=builder /root/trueblocks-explorer/api /root

COPY trueblocks.entrypoint.sh /root

RUN yarn install 2>/dev/null | grep -v fsevent && \
        npm install -g forever 2>/dev/null | grep -v fsevent && \
        mkdir -p /root/.quickBlocks/monitors /root/.quickBlocks/addr-index

# To make the shell easier to use
RUN apk add curl nano

EXPOSE 80

ENTRYPOINT bash /root/trueblocks.entrypoint.sh

