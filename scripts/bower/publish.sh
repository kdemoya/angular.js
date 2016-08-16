#!/bin/bash

# Script for updating the Angular bower repos from current local build.

echo "#################################"
echo "#### Update bower ###############"
echo "#################################"

ARG_DEFS=(
  "--action=(prepare|publish)"
)

function init {
  TMP_DIR=$(resolveDir ../../tmp)
  BUILD_DIR=$(resolveDir ../../build)
  NEW_VERSION=$(cat $BUILD_DIR/version.txt)
  PROJECT_DIR=$(resolveDir ../..)
  # get the npm dist-tag from a custom property (distTag) in package.json
  DIST_TAG=$(readJsonProp "$PROJECT_DIR/package.json" "distTag")
}


function prepare {
  #
  # clone repos
  #
  for repo in "${REPOS[@]}"
  do
    echo "-- Cloning $repo-juniper"
    git clone git@github.com:kdemoya/$repo-juniper.git $TMP_DIR/$repo-juniper
  done


  #
  # move the files from the build
  #

  for repo in "${REPOS[@]}"
  do
    if [ -f $BUILD_DIR/$repo.js ] # ignore i18l
      then
        echo "-- Updating files in $repo-juniper"
        cp $BUILD_DIR/$repo.* $TMP_DIR/$repo-juniper/
    fi
  done

  # move csp.css
  echo "-- Moving csp.css"
  cp $BUILD_DIR/angular-csp.css $TMP_DIR/angular-juniper/

  # move i18n files
  echo "-- Moving i18n files"
  cp -R $BUILD_DIR/i18n/*.js $TMP_DIR/$repo-juniper-i18n/



  #
  # Run local precommit script if there is one
  #
  for repo in "${REPOS[@]}"
  do
    if [ -f $TMP_DIR/$repo-juniper/precommit.sh ]
      then
        echo "-- Running precommit.sh script for $repo-juniper"
        cd $TMP_DIR/$repo-juniper
        $TMP_DIR/$repo-juniper/precommit.sh
        cd $SCRIPT_DIR
    fi
  done


  #
  # update bower.json
  # tag each repo
  #
  for repo in "${REPOS[@]}"
  do
    echo "-- Updating version in $repo-juniper to $NEW_VERSION"
    cd $TMP_DIR/$repo-juniper
    replaceJsonProp "bower.json" "version" ".*" "$NEW_VERSION"
    replaceJsonProp "bower.json" "angular.*" ".*" "$NEW_VERSION"
    replaceJsonProp "package.json" "version" ".*" "$NEW_VERSION"
    replaceJsonProp "package.json" "angular.*" ".*" "$NEW_VERSION"

    git add -A

    echo "-- Committing and tagging $repo-juniper"
    git commit -m "v$NEW_VERSION"
    git tag v$NEW_VERSION
    cd $SCRIPT_DIR
  done
}

function publish {
  for repo in "${REPOS[@]}"
  do
    echo "-- Pushing $repo-juniper"
    cd $TMP_DIR/$repo-juniper
    git push origin master
    git push origin v$NEW_VERSION

    # don't publish every build to npm
    if [ "${NEW_VERSION/+sha}" = "$NEW_VERSION" ] ; then
      echo "-- Publishing to npm as $DIST_TAG"
      npm publish --tag=$DIST_TAG
    fi

    cd $SCRIPT_DIR
  done
}

source $(dirname $0)/repos.inc
source $(dirname $0)/../utils.inc
