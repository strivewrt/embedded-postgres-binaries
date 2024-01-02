ARG BASE_IMG
FROM ${BASE_IMG}
WORKDIR /app
COPY go.mod /app/go.mod
COPY go.sum /app/go.sum
RUN go mod download
COPY embedded_postgres_test.go /app/embedded_postgres_test.go

RUN test -f /etc/alpine-release && apk add shadow || true
ARG USER_ID
ARG GROUP_ID
RUN groupadd -g ${GROUP_ID} postgres
RUN useradd -m -l -u ${USER_ID} -g postgres postgres
COPY versions /app/versions

USER postgres
CMD go test -v ./...