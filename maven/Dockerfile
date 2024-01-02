FROM golang:1.21-alpine as base
WORKDIR /app
RUN printf 'module maven\n\n\ngo 1.21.5\n' > /app/go.mod
COPY main.go /app/main.go
RUN go build -o /maven -a -ldflags '-extldflags "-static"' main.go

FROM scratch
COPY --from=base /maven /maven
ENTRYPOINT ["/maven"]