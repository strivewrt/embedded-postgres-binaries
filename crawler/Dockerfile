FROM alpine:3.19
RUN apk add curl wget
CMD until curl -s http://maven >/dev/null; do sleep 0.1; done && \
    wget -m --reject=jar http://maven