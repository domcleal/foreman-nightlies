#!/bin/bash

ret=0
date=$(date +%Y%m%d%H%M)

cd ~/nightlies
[ -e logs ] || mkdir logs

run() {
  if ! ./build.sh $* $date > logs/$1.log.$date 2>&1; then
    echo "Failure running ./build.sh $* $date"
    echo "Logs: $(pwd)/logs/$1.log.$date"
    echo
    cat logs/$1.log.$date
    echo
    echo
    ret=1
  fi
}

run foreman scl
run foreman-installer nonscl
run foreman-selinux nonscl
run smart-proxy nonscl

find logs -name "*.log.*" -mtime +14 -delete
exit $ret
