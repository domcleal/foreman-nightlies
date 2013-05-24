#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Usage: $0 <repo-name> <scl|nonscl> <build-date>"
  exit 1
fi

case "$2" in
  scl)
    args="--scl=ruby193"
    tag=""
    ;;
  nonscl)
    args=""
    tag="-nonscl"
    ;;
  *)
    exit 1
esac

set -xe

state=$(cd $(dirname $0); pwd)/state
[ -e $state ] || mkdir $state

TEMPDIR=$(mktemp -d)
trap "rm -rf $TEMPDIR" EXIT 
mkdir $TEMPDIR/repo

git clone -b develop https://github.com/theforeman/$1 $TEMPDIR/repo
cd $TEMPDIR/repo
date=$3
[ -z "$date" ] && date=$(date +%Y%m%d%H%M)
gitrev=$(git rev-parse --short HEAD)
release="${date}git${gitrev}"

[ -e $state/${1}-${gitrev} ] && exit 0

[ -e extras/packaging/rpm/rel-eng -a ! -e rel-eng ] && \
  git mv extras/packaging/rpm/rel-eng rel-eng
[ -e rel-eng/packages/foreman ] && rm -f rel-eng/packages/foreman

egrep -q "^Release:.*%" *.spec
sed -i "/^Release:/ s/%/.${release}%/" *.spec

EDITOR=/bin/cat tito tag --keep-version --auto-changelog-message="Automatic nightly build of ${gitrev}"

tito build --offline --srpm --dist=.el6 $args > $TEMPDIR/tito.out
srpm=$(tail -n1 $TEMPDIR/tito.out | sed "s/^Wrote: //g")
[ -e $srpm ]

koji -c ~/.koji/katello-config build foreman-nightly${tag}-rhel6 $srpm
rm -f $srpm

touch $state/${1}-${gitrev}
