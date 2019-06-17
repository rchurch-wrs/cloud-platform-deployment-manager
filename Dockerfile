# Build the manager binary
FROM golang:1.10.3 as dlvbuilder

# Build delve debugger
RUN apt-get update && apt-get install -y git
RUN go get github.com/derekparker/delve/cmd/dlv

FROM dlvbuilder as builder
ARG GOBUILD_GCFLAGS=""

# Copy in the go src
WORKDIR /go/src/github.com/wind-river/titanium-deployment-manager
COPY scripts/ scripts/
COPY pkg/     pkg/
COPY cmd/     cmd/
COPY vendor/  vendor/

# Build manager
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -gcflags "${GOBUILD_GCFLAGS}" -a -o manager github.com/wind-river/titanium-deployment-manager/cmd/manager

# Copy the controller-manager into a thin image
FROM scratch as production
WORKDIR /
COPY --from=builder /go/src/github.com/wind-river/titanium-deployment-manager/manager .
CMD "/manager"

# Copy the delve debugger into a debug image
FROM ubuntu:latest as debug
WORKDIR /
RUN apt-get update && apt-get install -y tcpdump net-tools iputils-ping iproute2
COPY --from=dlvbuilder /go/bin/dlv /
COPY --from=builder /go/src/github.com/wind-river/titanium-deployment-manager/manager .
COPY --from=builder /go/src/github.com/wind-river/titanium-deployment-manager/scripts/dlv-wrapper.sh /

CMD ["/dlv-wrapper.sh", "/manager"]