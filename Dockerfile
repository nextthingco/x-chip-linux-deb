FROM debian:trixie

# need a deb-src entry
COPY build.sources /etc/apt/sources.list.d

# grab build dependencies for cross compilation
# (this is intended to run on an amd64 host)
RUN dpkg --add-architecture armhf \
  && apt-get update \
  && apt-get -y install crossbuild-essential-armhf \
  && apt-get -y build-dep --arch-only -a armhf -P cross linux
