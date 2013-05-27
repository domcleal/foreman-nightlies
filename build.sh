#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Usage: $0 <repo-name> <scl|nonscl> <build-date>"
  exit 1
fi

repo=$1
scl=$2
date=$3
[ -z "$date" ] && date=$(date +%Y%m%d%H%M)

set -xe

state=$(cd $(dirname $0); pwd)/state
[ -e $state ] || mkdir $state

TEMPDIR=$(mktemp -d)
trap "rm -rf $TEMPDIR" EXIT 
mkdir $TEMPDIR/repo

git clone -b develop https://github.com/theforeman/$repo $TEMPDIR/repo
cd $TEMPDIR/repo
gitrev=$(git rev-parse --short HEAD)
release="${date}git${gitrev}"

[ -e $state/${1}-${gitrev} ] && exit 0

[ -e extras/packaging/rpm/rel-eng -a ! -e rel-eng ] && \
  git mv extras/packaging/rpm/rel-eng rel-eng
[ -e rel-eng/packages/foreman ] && rm -f rel-eng/packages/foreman

egrep -q "^Release:.*%" *.spec
sed -i "/^Release:/ s/%/.${release}%/" *.spec

EDITOR=/bin/cat tito tag --keep-version --auto-changelog-message="Automatic nightly build of ${gitrev}"

for osbuild in "rhel6:el6:scl" "fedora18:fc18:nonscl"; do
  os=$(echo $osbuild | cut -d: -f1)
  dist=$(echo $osbuild | cut -d: -f2)
  osscl=$(echo $osbuild | cut -d: -f3)

  tag=""
  args=""
  if [ $osscl = scl ]; then
    if [ $scl = scl ]; then
      args="--scl=ruby193"
    else
      tag="-nonscl"
    fi
  fi

  tito build --offline --srpm --dist=.${dist} $args > $TEMPDIR/tito.out
  srpm=$(tail -n1 $TEMPDIR/tito.out | sed "s/^Wrote: //g")
  [ -e $srpm ]

  koji -c ~/.koji/katello-config build foreman-nightly${tag}-${os} $srpm
  rm -f $srpm
done

touch $state/${1}-${gitrev}
