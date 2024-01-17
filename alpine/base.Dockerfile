FROM alpine:3.15

RUN apk add \
    build-base \
    ca-certificates \
    chrpath \
    coreutils \
    cmake \
    curl \
    g++ \
    gcc \
    icu-dev \
    json-c-dev \
    libc-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    linux-headers \
    make \
    openssl-dev \
    perl-dev \
    protobuf-c \
    protobuf-c-compiler \
    protobuf-c-dev \
    python3-dev \
    sqlite \
    sqlite-dev \
    sqlite-libs \
    tar \
    tcl-dev \
    unzip \
    util-linux-dev \
    wget \
    xz \
    zip \
    zlib-dev

ARG CONF_VERSION
RUN echo guess sub | xargs -n 1 | xargs -P 2 -I {} wget -O \
    /config.{} \
    "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.{};hb=$CONF_VERSION"

ARG PROJ_VERSION
ARG PROJ_DATUMGRID_VERSION
RUN mkdir -p /usr/src/proj \
    && curl -sL "https://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz" \
        | tar -xzf - -C /usr/src/proj --strip-components 1 \
    && cd /usr/src/proj \
    && curl -sL "https://download.osgeo.org/proj/proj-datumgrid-$PROJ_DATUMGRID_VERSION.zip" > proj-datumgrid.zip \
    && unzip -o proj-datumgrid.zip -d data\
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure --disable-static --prefix=/usr/local/pg-build \
    && make -j$(nproc) \
    && make install

ARG GEOS_VERSION
RUN mkdir -p /usr/src/geos \
    && curl -sL "https://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2" \
        | tar -xjf - -C /usr/src/geos --strip-components 1 \
    && cd /usr/src/geos \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure --disable-static --prefix=/usr/local/pg-build \
    && make -j$(nproc) \
    && make install

ARG GDAL_VERSION
RUN mkdir -p /usr/src/gdal \
    && curl -sL "https://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.xz" \
        | tar -xJf - -C /usr/src/gdal --strip-components 1 \
    && cd /usr/src/gdal \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure --disable-static --prefix=/usr/local/pg-build \
    && make -j$(nproc) \
    && make install