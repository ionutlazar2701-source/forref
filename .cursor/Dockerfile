FROM ubuntu:24.04

ARG FLUTTER_VERSION=3.47.2

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl git unzip xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && git clone --depth 1 --branch "${FLUTTER_VERSION}" \
       https://github.com/flutter/flutter.git /opt/flutter \
  && /opt/flutter/bin/flutter config --no-analytics \
  && /opt/flutter/bin/flutter precache --no-android --no-ios \
  && ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter \
  && ln -sf /opt/flutter/bin/dart /usr/local/bin/dart

USER ubuntu
