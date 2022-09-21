# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.63.0
ARG XX_VERSION=1.1.2

# xx is a helper for cross-compilation
#FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx
FROM --platform=$BUILDPLATFORM crazymax/xx:rust-rebased AS xx

FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION}-alpine as base
RUN apk add clang lld musl-dev gcc git file
COPY --from=xx / /
WORKDIR /work

FROM base AS cargo
COPY Cargo* .
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    cargo fetch

FROM cargo AS vendored
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index <<EOT
  set -e
  cargo update
  mkdir /out
  cp Cargo.lock /out
EOT

FROM scratch AS vendor
COPY --from=vendored /out /

FROM cargo AS build
ARG TARGETPLATFORM
RUN xx-apk add musl-dev gcc
RUN --mount=type=bind,target=.,rw \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    --mount=type=cache,target=/build/app,id=$TARGETPLATFORM <<EOT
  set -ex
  mkdir -p /out
  xx-cargo build --release --target-dir /build/app
  cp /build/app/$(xx-cargo --print-target)/release/rust-docker-cross /out/
  xx-verify --static /out/rust-docker-cross
EOT

FROM scratch AS binary
COPY --from=build /out /

FROM alpine:3.16 AS image
COPY --from=binary / /usr/local/bin
EXPOSE 3030
CMD ["/usr/local/bin/rust-docker-cross"]
