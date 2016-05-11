#!/usr/bin/env bash

# Exit if any error is encountered:
set -o errexit

# https://go.googlecode.com/files/go1.2.1.linux-amd64.tar.gz
# https://go.googlecode.com/files/go1.2.1.darwin-amd64-osx10.8.tar.gz
# uname -m (x86_64/386)
# uname (Linux/Darwin)
go_version(){
  local arch
  local os
  local osx_version
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

  ## osx version
  # sw_vers | grep 'ProductVersion:' | grep -o '[0-9]*\.[0-9]*'|head -n 1
  if [ $os == 'darwin' ]; then
    #osx_version='-osx'$(sw_vers | grep 'ProductVersion:' | grep -o '[0-9]*\.[0-9]*'|head -n 1)
    osx_version='-osx10.8'
  fi
  if [ $osx_version == '-osx10.9' ]; then
    osx_version='-osx10.8'
  fi

  echo $os-$arch$osx_version
}



## set the work directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/color-functions.sh

TMPDIR="$DIR/../tmp/install"
log_info "Will download golang, clone etcd repo and compile it into ${Red}tmp/install${RCol}"

mkdir -p $TMPDIR
cd $TMPDIR

## download everything
#file="go1.1.2.$(go_version).tar.gz"
file="go1.2.2.$(go_version).tar.gz"
if [ ! -e $file ]; then
  wget https://storage.googleapis.com/golang/$file
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
  cd etcd-repo && git fetch && cd ..
fi


export GOBIN=$TMPDIR/go/bin
export GOROOT=$TMPDIR/go
export PATH=$GOBIN:$PATH
cd etcd-repo
git checkout v0.1.2
./build
cd ..
cp etcd-repo/bin/etcd .
cp etcd-repo/bin/bench .
log_info "etcd binary with version ${Red} $(./etcd -version) ${RCol}is ready in $TMPDIR!"
log_info "copy to /usr/local/bin folder for system-wide installation "
log_info "just execute: ${Red}cp $TMPDIR/etcd /usr/local/bin/etcd ${RCol}"
