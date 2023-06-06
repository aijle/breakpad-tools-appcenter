#!/bin/sh

set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
  echo "Extract symbols and prepare symbols.zip file ready to upload to App Center."
  echo "Usage: $0 [-q] [*.so]"
  exit 0
fi

if [ "$1" = "-q" ] ; then
  QUIET=1
  shift
fi

if [ "$1" = "" ] ; then
  [ -z "$QUIET" ] && echo "Entering docker container..."
  exec docker run -it breakpad
  exit $?
fi

CUR_DIR=`pwd`

[ -z "$QUIET" ] && echo "Extracting symbols..."
SYM_DIR=${SYM_DIR:-`mktemp -d`}
mkdir -p "${SYM_DIR}"

for SO_FILE in $@ ; do
  echo "${SO_FILE}"
  if ! [[ -L "${SO_FILE}" ]]; then
    SO_DIR=`dirname ${SO_FILE}`
    SO_NAME=`basename ${SO_FILE}`
    SYM_FILE="${SYM_DIR}/${SO_NAME}.sym"
  
    docker run --name breakpad --rm -i -v ${SO_DIR}:/work/mnt -v ${SYM_DIR}:/work/output breakpad bash -c "/usr/local/bin/dump_syms /work/mnt/${SO_NAME} > /work/output/${SO_NAME}.sym" || true

    # cp -f "${SYM_FILE}" "${SYM_DIR}" || true
  fi
done

[ -z "$QUIET" ] && echo "Preparing zip archive..."
for SYM_FILE in `find ${SYM_DIR} -type f` ; do
  SO_ID=`head -n1 "${SYM_FILE}" |cut -d ' ' -f 4`
  SO_NAME=`head -n1 "${SYM_FILE}" |cut -d ' ' -f 5`
  echo "SYM_FILE: ${SYM_FILE}"
  echo "SYM_NAME: ${SYM_NAME}"
  echo "SO_ID: ${SO_ID}"

  mkdir -p "${SYM_DIR}/zip/${SO_NAME}/${SO_ID}"
  cp -f "${SYM_FILE}" "${SYM_DIR}/zip/${SO_NAME}/${SO_ID}/"
done

cd "${SYM_DIR}/zip"
zip -q -r "${CUR_DIR}/symbols.zip" *

[ -z "$QUIET" ] && echo "The symbols are ready for upload at:"
echo "${CUR_DIR}/symbols.zip"
