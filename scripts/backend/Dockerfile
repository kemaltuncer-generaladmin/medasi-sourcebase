FROM nginx:1.27-alpine

RUN mkdir -p /usr/share/nginx/html && \
  printf '%s\n' \
    '<!doctype html>' \
    '<html lang="en">' \
    '<head><meta charset="utf-8"><title>SourceBase Backend</title></head>' \
    '<body><pre>SourceBase backend bundle is healthy.</pre></body>' \
    '</html>' \
    > /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
