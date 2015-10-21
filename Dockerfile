FROM ubuntu:14.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
      build-essential \
      ca-certificates \
      curl \
      debhelper \
      dpkg-dev \
      g++ \
      gawk \
      gcc \
      git \
      grep \
      libbz2-dev \
      libgflags-dev \
      libsnappy-dev \
      make \
      python-httplib2 \
      scons \
      zlib1g-dev

# Install Go
RUN \
  mkdir -p /goroot && \
  curl https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz | tar xvzf - -C /goroot --strip-components=1

# Install jemalloc
RUN \
  curl -L https://github.com/jemalloc/jemalloc/releases/download/4.0.3/jemalloc-4.0.3.tar.bz2 | tar xjf - -C /jemalloc/ && \
  cd jemalloc-4.0.3 && \
  ./configure && \
  make -j$(nproc)
  make install

ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
ENV BUILD_DIR /mongobuild
ENV GIT_BRANCH master
ENV ROCKSDB_VERSION 4.1.fb
ENV MONGO_VERSION 3.2.0-rc0
ENV MONGO_ARCH mongodb-linux-x86_64-

RUN git clone --branch ${ROCKSDB_VERSION} https://github.com/facebook/rocksdb
WORKDIR rocksdb
RUN make -j$(nproc) release
RUN make -j$(nproc) install

WORKDIR ${BUILD_DIR}
RUN git clone --branch r${MONGO_VERSION} https://github.com/mongodb/mongo
WORKDIR ${BUILD_DIR}/mongo
RUN git clone --branch r${MONGO_VERSION} https://github.com/mongodb-partners/mongo-rocks src/mongo/db/modules/rocksdb
RUN git clone --branch r${MONGO_VERSION} https://github.com/mongodb/mongo-tools.git src/mongo-tools-repo
WORKDIR src/mongo-tools-repo/
RUN ./build.sh &&  mv bin/ ../mongo-tools/

WORKDIR ${BUILD_DIR}/mongo
RUN scons \
LINKFLAGS="-Wl,--whole-archive /usr/local/lib/libjemalloc.a -Wl,--no-whole-archive" \
CPPPATH=/usr/local/include \
LIBPATH=/usr/local/lib \
-j$(nproc) \
--release \
--use-new-tools \
--nostrip \
--allocator=system \
dist

RUN mkdir -p /artifacts && mv mongodb-linux-x86_64* /artifacts
