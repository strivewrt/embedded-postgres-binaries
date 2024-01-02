FROM docker.io/strivewrt/embedded-postgres-binaries:alpine-base as base

ARG PG_VERSION
# upstream postgres omits patch if .0
RUN mkdir -p /usr/src/postgresql \
    && export VERSION=$(echo $PG_VERSION | sed 's/\.0$//') \
    && curl -sL "https://ftp.postgresql.org/pub/source/v$VERSION/postgresql-$VERSION.tar.bz2" \
        | tar -xjf - -C /usr/src/postgresql --strip-components 1 \
    && cd /usr/src/postgresql \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure \
        CFLAGS="-Os" \
        PYTHON=/usr/bin/python3 \
        --prefix=/usr/local/pg-build \
        --enable-integer-datetimes \
        --enable-thread-safety \
        --with-uuid=e2fs \
        --with-gnu-ld \
        --with-includes=/usr/local/include \
        --with-libraries=/usr/local/lib \
        --with-icu \
        --with-libxml \
        --with-libxslt \
        --with-openssl \
        --with-perl \
        --with-python \
        --with-tcl \
        --without-readline \
    && make -j$(nproc) world \
    && make install-world

# 3.3.x supports pg 12-16, 3.3.5 is latest at this time
ARG POSTGIS_VERSION=3.3.5
RUN mkdir -p /usr/src/postgis \
    && curl -sL "https://postgis.net/stuff/postgis-$POSTGIS_VERSION.tar.gz" \
        | tar -xzf - -C /usr/src/postgis --strip-components 1 \
    && cd /usr/src/postgis \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure \
        --prefix=/usr/local/pg-build \
        --with-pgconfig=/usr/local/pg-build/bin/pg_config \
        --with-geosconfig=/usr/local/pg-build/bin/geos-config \
        --with-projdir=/usr/local/pg-build \
        --with-gdalconfig=/usr/local/pg-build/bin/gdal-config \
    && make -j$(nproc) \
    && make install

WORKDIR /usr/local/pg-build

RUN mkdir -p /usr/local/pg-build/lib \
    && cp /lib/libuuid.so.1 /lib/libz.so.1 /lib/libssl.so.1.1 /lib/libcrypto.so.1.1 /usr/lib/libxml2.so.2 /usr/lib/libxslt.so.1 ./lib \
    && cp --no-dereference /usr/lib/libicudata.so* /usr/lib/libicuuc.so* /usr/lib/libicui18n.so* /usr/lib/libstdc++.so* /usr/lib/libgcc_s.so* ./lib \
    && cp --no-dereference /usr/lib/libjson-c.so* /usr/lib/libsqlite3.so* /usr/lib/libprotobuf* /usr/lib/liblzma* ./lib \
    && find ./bin -type f \( -name "initdb" -o -name "pg_ctl" -o -name "postgres" \) -print0 | xargs -0 -n1 chrpath -r "\$ORIGIN/../lib" \
    && tar -cJvf /postgres-linux-alpine_linux.txz --hard-dereference \
        share/postgresql \
        lib \
        bin/initdb \
        bin/pg_ctl \
        bin/postgres

RUN zip -9 /embedded-postgres-binaries-linux-amd64-alpine-$PG_VERSION.jar /postgres-linux-alpine_linux.txz

FROM busybox:1.36.1
ARG PG_VERSION
ENV PG_VERSION=$PG_VERSION
WORKDIR /out
COPY --from=base \
    /embedded-postgres-binaries-linux-amd64-alpine-$PG_VERSION.jar \
    /embedded-postgres-binaries-linux-amd64-alpine-$PG_VERSION.jar
CMD cp /embedded-postgres-binaries-linux-amd64-alpine-$PG_VERSION.jar /out