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
      python-pymongo \
      scons \
      zlib1g-dev

ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
ENV BUILD_DIR /mongobuild
ENV GO_VERSION 1.5.1
ENV JEMALLOC_VERSION 4.0.3
ENV ROCKSDB_VERSION 4.1.fb
ENV MONGO_VERSION 3.2.0-rc0
ENV MONGO_ARCH mongodb-linux-x86_64-

# Install Go
RUN \
  mkdir -p /goroot && \
  curl https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz | tar xzf - -C /goroot --strip-components=1

# Install jemalloc
RUN \
  mkdir /jemalloc && \
  curl -L https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2 | tar xjf - -C /jemalloc/ && \
  cd /jemalloc/jemalloc-${JEMALLOC_VERSION} && \
  ./configure && \
  make -j$(nproc) && \
  make install

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

#build enviornment to run tests
RUN scons \
LINKFLAGS="-Wl,--whole-archive /usr/local/lib/libjemalloc.a -Wl,--no-whole-archive" \
CPPPATH=/usr/local/include \
LIBPATH=/usr/local/lib \
-j$(nproc) \
--release \
--use-new-tools \
--nostrip \
--allocator=system \
build/unittests/storage_rocks_index_test \
build/unittests/storage_rocks_engine_test \
build/unittests/storage_rocks_record_store_test \
mongo \
mongod

#build tarball
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
