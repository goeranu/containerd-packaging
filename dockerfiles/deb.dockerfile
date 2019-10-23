ARG BUILD_IMAGE=ubuntu:bionic
# Install golang since the package managed one probably is too old and ppa's don't cover all distros
ARG GOLANG_IMAGE

FROM ${GOLANG_IMAGE} AS golang

FROM alpine:3.10 AS git
RUN apk -u --no-cache add git

FROM git AS containerd-src
ARG REF=master
RUN git clone https://github.com/containerd/containerd.git /containerd
RUN git -C /containerd checkout "${REF}"

FROM git AS runc-src
ARG RUNC_REF=master
RUN git clone https://github.com/opencontainers/runc.git /runc
RUN git -C /runc checkout "${RUNC_REF}"

FROM golang AS go-md2man
RUN go get github.com/cpuguy83/go-md2man

FROM ${BUILD_IMAGE}
RUN cat /etc/os-release

# Install some pre-reqs
RUN apt-get update && apt-get install -y curl devscripts equivs git lsb-release

RUN mkdir -p /go
ENV GOPATH=/go
ENV PATH="${PATH}:/usr/local/go/bin:${GOPATH}/bin"
ENV IMPORT_PATH=github.com/containerd/containerd
ENV GO_SRC_PATH="/go/src/${IMPORT_PATH}"

# Set up debian packaging files
COPY common/ /root/common/
COPY debian/ /root/containerd/debian/
WORKDIR /root/containerd

# Install all of our build dependencies, if any
RUN mk-build-deps -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" -i debian/control

# Copy over our entrypoint
COPY scripts/build-deb /build-deb
COPY scripts/.helpers /.helpers

COPY --from=go-md2man      /go/bin/go-md2man /go/bin/go-md2man
COPY --from=golang         /usr/local/go/    /usr/local/go/
COPY --from=containerd-src /containerd/      /go/src/github.com/containerd/containerd/
COPY --from=runc-src       /runc/            /go/src/github.com/opencontainers/runc/

ARG PACKAGE
ENV PACKAGE=${PACKAGE:-containerd.io}
ENTRYPOINT ["/build-deb"]
