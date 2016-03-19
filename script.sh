#!/usr/bin/env bash

MASON_NAME=rust
MASON_VERSION=1.7.0
MASON_LIB_FILE=root/bin/rustc

. ${MASON_DIR:-~/.mason}/mason.sh

if [ -f ${MASON_PREFIX}/setup.sh ]; then
    . ${MASON_PREFIX}/setup.sh
fi

function mason_load_source {
    mkdir -p ${MASON_ROOT}
    echo ${MASON_ROOT}
    export MASON_BUILD_PATH=${MASON_ROOT}/../toolchain/${MASON_PLATFORM}
}

function mason_compile {
    mkdir -p ${MASON_PREFIX}
    cp -av ${MASON_BUILD_PATH}/* ${MASON_PREFIX}/
}

function mason_cflags {
    :
}

function mason_ldflags {
    :
}

mason_run "$@"
