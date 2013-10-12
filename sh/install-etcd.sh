#!/usr/bin/env bash

# https://go.googlecode.com/files/go1.1.2.linux-386.tar.gz
# https://go.googlecode.com/files/go1.1.2.darwin-386.tar.gz
# https://go.googlecode.com/files/go1.1.2.linux-amd64.tar.gz
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
TMPDIR="$DIR/../tmp/install"
echo "Will download golang, clone etcd repo and compile it into:"
echo $TMPDIR

mkdir -p $TMPDIR
cd $TMPDIR

## download everything
file="go1.1.2.$(go_version).tar.gz"
if [ ! -e $file ]; then
  wget https://go.googlecode.com/files/$file
fi

if [ ! -d 'go' ]; then
  tar xfvz $file
fi

if [ ! -d 'etcd-repo' ]; then
  git clone https://github.com/coreos/etcd.git etcd-repo
fi


export GOBIN=$TMPDIR/go/bin
export PATH=$GOBIN:$PATH
cd etcd-repo
./build
cd ..
cp etcd-repo/etcd .
echo "etcd binary with version $(./etcd -version) is ready in $TMPDIR!"
echo "for system-wide installation copy to /usr/local/bin folder!"
echo "just execute: cp $TMPDIR/etcd /usr/local/bin/etcd"