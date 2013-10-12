#!/usr/bin/env bash

# https://go.googlecode.com/files/go1.1.2.linux-386.tar.gz
# https://go.googlecode.com/files/go1.1.2.darwin-amd64.tar.gz
# uname -m (x86_64/386)
# uname (Linux/Darwin)
go_version(){
  local arch
  local os
  if [[ $(uname -m) =~ ^x86_64.* ]]; then
    arch='amd64'
  else
    arch='386'
  fi

  if [[ $(uname) =~ ^Darwin.* ]]; then
    os='darwin'
  else
    os='linux'
  fi

  echo $os-$arch
}


## set the work directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/color-functions.sh

TMPDIR="$DIR/../tmp/install"
log_info "Will download golang, clone etcd repo and compile it into ${Red}tmp/install${RCol}"

mkdir -p $TMPDIR
cd $TMPDIR

## download everything
file="go1.1.2.$(go_version).tar.gz"
if [ ! -e $file ]; then
  wget https://go.googlecode.com/files/$file
else
  log_debug "$file already downloaded..."
fi

if [ ! -d 'go' ]; then
  tar xfvz $file
else
  log_debug "go already uncompressed..."
fi

if [ ! -d 'etcd-repo' ]; then
  git clone https://github.com/coreos/etcd.git etcd-repo
else
  log_debug "etcd-repo already cloned, updating..."
  cd etcd-repo && git pull && cd ..
fi


export GOBIN=$TMPDIR/go/bin
export PATH=$GOBIN:$PATH
cd etcd-repo
./build
cd ..
cp etcd-repo/etcd .
log_info "etcd binary with version ${Red} $(./etcd -version) ${RCol}is ready in $TMPDIR!"
log_info "copy to /usr/local/bin folder for system-wide installation "
log_info "just execute: ${Red}cp $TMPDIR/etcd /usr/local/bin/etcd ${RCol}"