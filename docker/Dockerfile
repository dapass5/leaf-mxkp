FROM ghcr.io/utility-muffin-research-kitchen/mlp1-toolchain@sha256:3fa668ce6d399f57f1d391e8a8253f5017ab6d52e71b97ce5b1e955868124014
RUN sed -i 's,http://,https://,g' /etc/apt/sources.list.d/ubuntu.sources \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential ruby autoconf automake libtool bison python3-pip \
 && /usr/bin/python3 -m pip install --break-system-packages meson==1.10.2 \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
ENV PATH="/usr/local/bin:/opt/mlp1-toolchain/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
