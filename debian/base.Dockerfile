FROM ubuntu:20.04

RUN ln -snf /usr/share/zoneinfo/Etc/UTC /etc/localtime && echo "Etc/UTC" > /etc/timezone

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bzip2 \
    ca-certificates \
    cmake \
    curl \
    g++ \
    gcc \
    libc-dev \
    libicu-dev \
    libjson-c-dev \
    libjsoncpp-dev \
    libossp-uuid-dev \
    libperl-dev \
    libprotobuf-c-dev \
    libprotobuf-dev \
    libsqlite3-0 \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libz-dev \
    make \
    pkg-config \
    protobuf-c-compiler \
    python3-dev \
    sqlite3 \
    tcl-dev \
    unzip \
    wget \
    xz-utils \
    zip

ARG CONF_VERSION
RUN echo guess sub | xargs -n 1 | xargs -P 2 -I {} wget -O \
    /config.{} \
    "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.{};hb=$CONF_VERSION"

ARG PATCHELF_VERSION
RUN mkdir -p /usr/src/patchelf \
    && curl -sL "https://nixos.org/releases/patchelf/patchelf-$PATCHELF_VERSION/patchelf-$PATCHELF_VERSION.tar.gz" \
        | tar -xzf - -C /usr/src/patchelf --strip-components 1 \
    && cd /usr/src/patchelf \
    && cp /config.guess config.guess \
    && cp /config.sub config.sub \
    && ./configure --prefix=/usr/local \
    && make -j$(nproc) \
    && make install

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