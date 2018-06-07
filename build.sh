#!/bin/sh

set -e

git config --global user.email xie@yihui.name
git config --global user.name "Yihui Xie"

git fetch origin gh-pages:gh-pages

Rscript build.R

[ "${TRAVIS_PULL_REQUEST}" != "false" ] && exit 0

git checkout gh-pages
git add -A
git commit --amend -m"Publishing from Travis build $TRAVIS_BUILD_NUMBER"
git push -fq https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git gh-pages > /dev/null
