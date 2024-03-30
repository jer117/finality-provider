FROM golang:1.21-bullseye AS go-builder

# Set Golang environment variables.
ENV GOPATH=/go
ENV PATH=$PATH:/go/bin

# Install dependencies
ENV PACKAGES git make gcc musl-dev wget ca-certificates build-essential
RUN apt-get update
RUN apt-get install -y $PACKAGES

# Update ca certs
RUN update-ca-certificates

ARG VERSION=v0.1.0

# for COSMWASM_VERSION check here https://github.com/babylonchain/babylon/blob/dev/go.mod
ARG COSMWASM_VERSION=v0.50.0

# for COSMWASM_VM_VERSION be sure to check the compatibility section in the README.md file here (https://github.com/CosmWasm/wasmd)
ARG COSMWASM_VM_VERSION=v1.5.2

# Install cosmwasm lib
RUN git clone https://github.com/CosmWasm/wasmd.git \
 	&& cd wasmd \
 	&& git checkout $COSMWASM_VERSION \
 	&& go mod download \
    && go mod edit -replace github.com/CosmWasm/wasmvm=github.com/CosmWasm/wasmvm@v1.5.2 \
    && go mod tidy && make install \
	&& find / -name libwasmvm.x86_64.so \
    && cp /go/pkg/mod/github.com/!cosm!wasm/wasmvm@v1.5.2/internal/api/libwasmvm.x86_64.so /usr/lib

RUN git clone https://github.com/babylonchain/finality-provider.git \
    && cd finality-provider \ 
    && make install 

# Final image
FROM ubuntu:jammy

# Install ca-certificates
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y ca-certificates curl wget jq git \
    && apt-get -y purge && apt-get -y clean \
    && apt-get -y autoremove && rm -rf /var/lib/apt/lists/*

# Copy over binary from the builder layer
COPY --from=go-builder /usr/lib/libwasmvm.x86_64.so /usr/lib
COPY --from=go-builder /go/bin/eotsd /usr/bin/eotsd
COPY --from=go-builder /go/bin/fpd /usr/bin/fpd
COPY --from=go-builder /go/bin/fpcli /usr/bin/fpcli

# Run the binary.
CMD ["/bin/sh"]

COPY . .

ENV SHELL /bin/bash
