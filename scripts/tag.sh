#!/usr/bin/env sh
set -e
if [ "$1" == "" ]; then
  echo usage: "$0 VERSION"
fi
git tag $1
git push origin $1
