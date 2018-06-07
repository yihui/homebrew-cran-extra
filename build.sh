#!/bin/sh

set -e

git fetch origin gh-pages:gh-pages
git checkout gh-pages

Rscript build.R

[ "${TRAVIS_PULL_REQUEST}" != "false" ] && exit 0

git add -A
git commit --amend -m"Publishing from Travis build $TRAVIS_BUILD_NUMBER"
git push -fq https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git origin gh-pages > /dev/null
