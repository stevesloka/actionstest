FROM golang:1.13rc2 AS build
WORKDIR /actionstest

ENV GOPROXY=https://proxy.golang.org
COPY go.mod ./
RUN go mod download

COPY cmd cmd
RUN CGO_ENABLED=0 GOOS=linux GOFLAGS=-ldflags=-w go build -o /go/bin/actionstest -ldflags=-s -v github.com/stevesloka/actionstest/contour/

FROM scratch AS final
COPY --from=build /go/bin/actionstest /bin/actionstest
CMD ["/bin/actionstest"]

