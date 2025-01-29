FROM golang:1.23.1-bullseye AS go-builder

# Set Golang environment variables.
ENV GOPATH=/go
ENV PATH=$PATH:/go/bin

# Install dependencies
RUN apt-get update && apt-get install -y git make gcc musl-dev wget ca-certificates build-essential \
    && update-ca-certificates \
    && apt-get clean

# renovate: datasource=github-releases depName=babylonlabs-io/babylon
ARG VERSION=v0.15.0

ARG COSMWASM_VM_VERSION=v2.1.3

# Set the working directory
WORKDIR /go/src/github.com/babylonlabs-io/finality-provider

# Download wasmvm libraries
RUN wget -q https://github.com/CosmWasm/wasmvm/releases/download/${COSMWASM_VM_VERSION}/libwasmvm.x86_64.so -O /lib/libwasmvm.x86_64.so

# Verify checksums
RUN sha256sum /lib/libwasmvm.x86_64.so | grep 0dd3c88d619b75e73d986ceeedb57410e6df7047915839fa186e66a841d6219a

# Create a symlink for easier access
RUN cp "/lib/libwasmvm.$(uname -m).so" /lib/libwasmvm.so

# Clone finality provider and build it
RUN git clone https://github.com/babylonlabs-io/finality-provider.git \
    && cd finality-provider \
    && git checkout tags/$VERSION \
    && make build \
    && make install

# Final image
FROM ubuntu:jammy

# Install ca-certificates and other necessary packages
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y ca-certificates curl wget jq git \
    && apt-get clean

# Copy over binaries from the builder layer
COPY --from=go-builder /lib/libwasmvm.x86_64.so /usr/lib/
COPY --from=go-builder /go/bin/eotsd /usr/bin/eotsd
COPY --from=go-builder /go/bin/fpd /usr/bin/fpd

# Run the binary.
CMD ["/bin/sh"]
