FROM alpine:3.18

EXPOSE 1194 1701 1723 1812/udp 1813/udp 21 22 23 443 4500/udp 50 500/udp 51 2021 2022 2023 2027 5900 80 8080 8291 8728 8729 8900

WORKDIR /chr

RUN apk add --no-cache --update \
    netcat-openbsd qemu-system-x86_64 \
    busybox-extras iproute2 iputils \
    bridge-utils iptables jq bash python3

# Copy script to routeros folder
ADD ["./scripts", "/chr"]

# MAC address for Router interface
ENV HWADDR="44:55:AB:CD:EF:01"

ENV VER="7.11"
ENV IMAGE="chr-$VER.img"
ENV DOWNLOAD_URL="https://download.mikrotik.com/routeros/$VER/$IMAGE.zip"

RUN wget "$DOWNLOAD_URL" -O "/chr/$IMAGE.zip"
RUN unzip "$IMAGE.zip" && rm "$IMAGE.zip"

ENTRYPOINT ["/chr/run.sh"]
