# syntax=docker/dockerfile:1.4
ARG BASE_IMAGE=ubuntu:20.04
ARG BASE_RUNTIME_IMAGE=nvcr.io/nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

FROM ${BASE_IMAGE} AS python-env

ARG DEBIAN_FRONTEND=noninteractive
ARG PYENV_VERSION=v2.3.13
ARG PYTHON_VERSION=3.8.10

RUN <<EOF
    set -eu

    apt-get update

    apt-get install -y \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        curl \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev \
        git

    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOF

RUN <<EOF
    set -eu

    git clone https://github.com/pyenv/pyenv.git /opt/pyenv
    cd /opt/pyenv
    git checkout "${PYENV_VERSION}"

    PREFIX=/opt/python-build /opt/pyenv/plugins/python-build/install.sh
    /opt/python-build/bin/python-build -v "${PYTHON_VERSION}" /opt/python

    rm -rf /opt/python-build /opt/pyenv
EOF


FROM ${BASE_RUNTIME_IMAGE} AS runtime-env

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH=/home/user/.local/bin:/opt/python/bin:${PATH}

COPY --from=python-env /opt/python /opt/python

RUN <<EOF
    set -eu

    apt-get update
    apt-get install -y \
        git \
        gosu
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOF

RUN <<EOF
    set -eu

    groupadd -o -g 1000 user
    useradd -m -o -u 1000 -g user user
EOF

ARG TI_URL=https://github.com/rinongal/textual_inversion
ARG TI_VERSION=26ed44fb62c00d6a39d26212a0510466cccebd59

RUN <<EOF
    set -eu

    mkdir -p /work
    chown -R user:user /work

    gosu user git clone "${TI_URL}" /work/textual_inversion
    cd /work/textual_inversion
    gosu user git checkout "${TI_VERSION}"
EOF

WORKDIR /work/textual_inversion
ADD ./requirements.txt /work/textual_inversion/
RUN <<EOF
    set -eu

    gosu user pip3 install -r ./requirements.txt
EOF
