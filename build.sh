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

git clone --recursive -b develop https://github.com/theforeman/$repo $TEMPDIR/repo
cd $TEMPDIR/repo
gitrev=$(git rev-parse --short HEAD)
release="${date}git${gitrev}"

[ -e $state/${1}-${gitrev} ] && exit 0

[ -e extras/packaging/rpm/rel-eng -a ! -e rel-eng ] && \
  git mv extras/packaging/rpm/rel-eng rel-eng
[ -e rel-eng/packages/foreman ] && rm -f rel-eng/packages/foreman

egrep -q "^Release:.*%" *.spec
sed -i "/^Release:/ s/%/.${release}%/" *.spec

if [ -e release ]; then
  version=$(rpm -q --specfile --qf "%{VERSION}" *.spec)
  git tag -m $version $version
  # FIXME: no %changelog entry
else
  EDITOR=/bin/cat tito tag --keep-version --auto-changelog-message="Automatic nightly build of ${gitrev}"
fi

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

  if [ -e release ]; then
    ./release $version .${dist} > $TEMPDIR/build.out
  else
    tito build --offline --srpm --dist=.${dist} $args > $TEMPDIR/build.out
  fi
  srpm=$(grep Wrote $TEMPDIR/build.out | tail -n1 | sed "s/^Wrote: //g")
  [ -e $srpm ]

  koji -c ~/.koji/katello-config build foreman-nightly${tag}-${os} $srpm
  rm -f $srpm
done

touch $state/${1}-${gitrev}
