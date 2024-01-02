FROM alpine:3.15

ARG hb=b8ee5f79949d1d40e8820a774d813660e1be52d3
RUN apk add \
    ca-certificates \
    chrpath \
    coreutils \
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
    zlib-dev \
    && wget -O /config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=${hb}" \
    && wget -O /config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=${hb}"

ARG PROJ_VERSION=6.1.0
ARG PROJ_DATUMGRID_VERSION=1.8
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

ARG GEOS_VERSION=3.7.2
RUN mkdir -p /usr/src/geos \
    && curl -sL "https://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2" \
        | tar -xjf - -C /usr/src/geos --strip-components 1 \
    && cd /usr/src/geos \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure --disable-static --prefix=/usr/local/pg-build \
    && make -j$(nproc) \
    && make install

ARG GDAL_VERSION=2.4.1
RUN mkdir -p /usr/src/gdal \
    && curl -sL "https://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.xz" \
        | tar -xJf - -C /usr/src/gdal --strip-components 1 \
    && cd /usr/src/gdal \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure --disable-static --prefix=/usr/local/pg-build \
    && make -j$(nproc) \
    && make install