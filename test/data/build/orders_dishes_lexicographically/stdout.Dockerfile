ARG Foo=''
ARG bar=''
ARG foo=''

FROM alpine:latest

ARG bar
ARG Foo
ARG foo
RUN if [[ -n "${bar}" ]]; then \
    echo 'bar' \
  ; fi \
  && if [[ -n "${Foo}" ]]; then \
    echo 'Foo' \
  ; fi \
  && if [[ -n "${foo}" ]]; then \
    echo 'foo' \
  ; fi
