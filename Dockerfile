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

ENV GOROOT /goroot
ENV GOPATH /gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
ENV BUILD_DIR /mongobuild
ENV GIT_BRANCH master
ENV ROCKSDB_VERSION rocksdb-3.13.1
ENV MONGO_VERSION 3.2.0-rc0
ENV MONGO_ARCH mongodb-linux-x86_64-

RUN curl --location https://github.com/facebook/rocksdb/archive/${ROCKSDB_VERSION}.tar.gz | tar xz
WORKDIR rocksdb-${ROCKSDB_VERSION}
RUN make -j32 release
RUN make -j32 install

WORKDIR ${BUILD_DIR}
RUN git clone --branch r${MONGO_VERSION} https://github.com/mongodb/mongo
WORKDIR ${BUILD_DIR}/mongo
RUN git clone --branch r${MONGO_VERSION} https://github.com/mongodb-partners/mongo-rocks src/mongo/db/modules/rocksdb
RUN git clone --branch r${MONGO_VERSION} https://github.com/mongodb/mongo-tools.git src/mongo-tools-repo
WORKDIR src/mongo-tools-repo/
RUN ./build.sh &&  mv bin/ ../mongo-tools/

WORKDIR ${BUILD_DIR}/mongo
RUN scons \
      -j32 \
      --release \
      --use-new-tools \
      dist

#WORKDIR ${BUILD_DIR}/mongo/buildscripts
#RUN python packager.py --tarball=${BUILD_DIR}/mongo/${MONGO_ARCH}${MONGO_VERSION}.tgz -d ubuntu1404 -s ${MONGO_VERSION} -m ${GIT_BRANCH} || true
#RUN mv $(find  /tmp/tmp* -maxdepth 0 | head -1) /debs
