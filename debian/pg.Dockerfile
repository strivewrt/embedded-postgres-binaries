ARG FROM
FROM $FROM as base

ARG PG_VERSION
# upstream postgres omits patch if .0
RUN mkdir -p /usr/src/postgresql \
    && export VERSION=$(echo $PG_VERSION | sed 's/\.0$//') \
    && curl -sL "https://ftp.postgresql.org/pub/source/v$VERSION/postgresql-$VERSION.tar.bz2" \
        | tar -xjf - -C /usr/src/postgresql --strip-components 1 \
    && cd /usr/src/postgresql \
    && cp /config.guess config/config.guess \
    && cp /config.sub config/config.sub \
    && ./configure \
        CFLAGS="-Os -DMAP_HUGETLB=0x40000" \
        PYTHON=/usr/bin/python3 \
        --prefix=/usr/local/pg-build \
        --enable-integer-datetimes \
        --enable-thread-safety \
        --with-ossp-uuid \
        --with-icu \
        --with-libxml \
        --with-libxslt \
        --with-openssl \
        --with-perl \
        --with-python \
        --with-tcl \
        --without-readline \
    && make -j$(nproc) world \
    && make install-world \
    && make -C contrib install

# 3.3.x supports pg 12-16
ARG POSTGIS_VERSION
ENV LD_LIBRARY_PATH=/usr/local/pg-build/lib
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
    && cp /usr/lib/libossp-uuid.so.16 ./lib || cp /usr/lib/*/libossp-uuid.so.16 ./lib \
    && cp /lib/*/libz.so.1 /lib/*/liblzma.so.5 /usr/lib/*/libxml2.so.2 /usr/lib/*/libxslt.so.1 ./lib \
    && cp /lib/*/libssl.so.1* /lib/*/libcrypto.so.1* ./lib || cp /usr/lib/*/libssl.so.1* /usr/lib/*/libcrypto.so.1* ./lib \
    && cp --no-dereference /usr/lib/*/libicudata.so* /usr/lib/*/libicuuc.so* /usr/lib/*/libicui18n.so* ./lib \
    && cp --no-dereference /lib/*/libjson-c.so* /usr/lib/*/libsqlite3.so* ./lib \
    && cp --no-dereference /usr/lib/*/libprotobuf* ./lib \
    && find ./bin -type f \( -name "initdb" -o -name "pg_ctl" -o -name "postgres" \) -print0 | xargs -0 -n1 patchelf --set-rpath "\$ORIGIN/../lib" \
    && find ./lib -maxdepth 1 -type f -name "*.so*" -print0 | xargs -0 -n1 patchelf --set-rpath "\$ORIGIN" \
    && find ./lib/postgresql -maxdepth 1 -type f -name "*.so*" -print0 | xargs -0 -n1 patchelf --set-rpath "\$ORIGIN/.." \
    && tar -cJvf /postgres-linux-debian.txz --hard-dereference \
        share/postgresql \
        lib \
        bin/initdb \
        bin/pg_ctl \
        bin/postgres

RUN zip -9 /embedded-postgres-binaries-linux-amd64-$PG_VERSION.jar /postgres-linux-debian.txz

FROM busybox:1.36.1
ARG PG_VERSION
ENV PG_VERSION=$PG_VERSION
WORKDIR /out
COPY --from=base \
    /embedded-postgres-binaries-linux-amd64-$PG_VERSION.jar \
    /embedded-postgres-binaries-linux-amd64-$PG_VERSION.jar
CMD cp /embedded-postgres-binaries-linux-amd64-$PG_VERSION.jar /out