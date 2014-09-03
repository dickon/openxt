#!/bin/bash -e

BUILD_TYPE=openxt
FORCE_TAG=
USER=

while [ "$#" -ne 0 ]; do
  case "$1" in 
    -t) BUILD_TYPE="$2"; shift 2;;
    -r) RSYNC_DEST="$2"; shift 2;;
    -f) FORCE_TAG="-f"; shift ;;
    -u) USER="--user $2"; shift 2;;
    -d) DONOTFETCH=1; shift ;;
    *) break 
  esac
done

echo "have $# args"
if [ "$#" -ne 3 ] 
then
  echo "usage: build_tag.sh [-d] [-u GITHUB_USER] [-f] [-t BUILD_TYPE] [-r RSYNC_DEST] SITE BRANCH BUILD_DIRECTORY"
  exit 1
fi

SITE=${1}
BRANCH=${2}
BUILDD=${3}
REPOS=${3}/openxt-replica



[ ! -d $BUILDD ] && mkdir -p ${BUILDD}

function cleanup {
  cd ${BUILDD}
  for b in openxt-${SITE}-${BUILD_TYPE}* ; do
    rm -rf ${b}/build ${b}/misc ${b}/build-output/*/iso/source*.iso ${b}/build-output/*/raw/source
    [ -f ${b}/build.log ] && gzip ${b}/build.log
  done
  echo cleanup done
}

cleanup
cd ${BUILDD}
[ ! -d scripts ] && git clone https://github.com/dickon/scripts.git # TODO: use openxt-extras scripts once changes are merged
[ ! -d build-machines ] && git clone https://github.com/dickon/build-machines.git # TODO: use openxt-extras build-machines once changes are merged
REPOS=${BUILDD}/openxt-replica
if [ -z ${DONOTFETCH} ]; then
  scripts/replicate_github.py openxt ${REPOS} ${USER}
fi
umask 0022
TAGNUM=$(build-machines/do_tag.py -b ${BRANCH} -r ${REPOS} ${SITE}-${BUILD_TYPE}- -i openxt -t ${FORCE_TAG}) || TAGNUM=
if [ -z ${TAGNUM} ]; then 
  echo no tag needed
else
  echo tagnum is ${TAGNUM}
  TAG=${SITE}-${BUILD_TYPE}-${TAGNUM}-${BRANCH}
  echo tag is ${TAG}
  git clone ${REPOS}/openxt.git openxt-${TAG}
  cd openxt-${TAG}
  mkdir -p misc/oe/oe-download
  git checkout ${TAG}
  cp example-config .config
  cat <<EOF >> .config
OPENXT_GIT_MIRROR="file://${REPOS}"
REPO_PROD_CACERT="${BUILDD}/certs/prod-cacert.pem"
REPO_DEV_CACERT="${BUILDD}/certs/dev-cacert.pem"
REPO_DEV_SIGNING_CERT="${BUILDD}/certs/dev-cacert.pem"
REPO_DEV_SIGNING_KEY="${BUILDD}/certs/dev-cakey.pem"
NAME_SITE="$SITE"
BUILD_TYPE="$BUILD_TYPE"
EOF
  ./do_build.sh -b ${BRANCH} -S -i ${TAGNUM} | tee build.log
  ret=${PIPESTATUS[0]}
  cleanup
fi

if [ -n ${RSYNC_DEST} ]; then
  echo rsyncing ${BUILDD} to ${RSYNC_DEST}
  rsync -v --exclude certs --exclude scripts --exclude build-machines --chmod=ugo=rwX -r ${BUILDD}/ ${RSYNC_DEST}
fi

exit $ret
