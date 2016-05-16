#!/usr/bin/env bash

# Exit if any error is encountered:
set -o errexit

ETCD_VERSION='2.3.3'

## set the work directory
DIR="$(pwd)/$(dirname $0)"
source $DIR/color-functions.sh

TMPDIR="$(dirname $DIR)/tmp/install"
log_info "Will download binary release of etcd v${ETCD_VERSION} into ${Red}tmp/install${RCol}"

mkdir -p $TMPDIR
cd $TMPDIR

## download etcd
if [[ $(uname) =~ ^Darwin.* ]]; then
  etcd_pkg_basename=etcd-v${ETCD_VERSION}-darwin-amd64
  etcd_pkg_suffix=.zip
  unpack_cmd='unzip'
else
  etcd_pkg_basename=etcd-v${ETCD_VERSION}-linux-amd64
  etcd_pkg_suffix=.tar.gz
  unpack_cmd='tar zxvf'
fi

if [ ! -d ${etcd_pkg_basename} ]; then
  etcd_package=${etcd_pkg_basename}${etcd_pkg_suffix}
  curl -L  https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/${etcd_package} -o ${etcd_package}
  ${unpack_cmd} ${etcd_package}
else
  log_debug "previous etcd package download found"
fi

cp ${etcd_pkg_basename}/etcd $TMPDIR
cp ${etcd_pkg_basename}/etcdctl $TMPDIR

log_info "etcd binary with version ${Red} $(./etcd --version | grep etcd) ${RCol}is ready in $TMPDIR!"
log_info "copy to /usr/local/bin folder for system-wide installation "
log_info "just execute: ${Red}cp $TMPDIR/etcd /usr/local/bin/etcd ${RCol}"
