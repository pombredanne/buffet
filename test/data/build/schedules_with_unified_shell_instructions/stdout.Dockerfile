ARG bar=''
ARG foo=''

FROM alpine:3.10.2
ARG bar
ARG foo
SHELL ["/bin/sh", "-o", "pipefail", "-c"]