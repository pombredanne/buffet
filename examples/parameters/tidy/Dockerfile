ARG alpine='3.11.5'

FROM alpine:"${alpine}"
ARG tidy

# hadolint ignore=DL3018
RUN apk add --no-cache "tidyhtml${tidy}"

WORKDIR /workdir
