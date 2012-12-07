#!/bin/bash

################################################################################
#
# (C) 2012 by Michael Gissing
#
# FloppyBkp licensed under GPLv2 - see file LICENSE
#
################################################################################

################################################################################
# Configuration

BASE_DIR="${HOME}/.floppybkp"
FLOPPY_DEV="/dev/fd0"
SUDO_CMD="sudo"

################################################################################
# some functions

err() {
  echo "ERROR: ${1}"
  exit 1
}

inf() {
  echo "INFO:  ${1}"
}

chk_crt_dir() {
  if [[ -e "${1}" ]] && [[ ! -d "${1}" ]]; then
    err "file ${1} exists but is not a directory"
  elif [[ ! -e "${1}" ]]; then
    mkdir "${1}"
  fi
}

################################################################################
# the code

SUDO=""
[[ $EUID == 0 ]] || SUDO+=$SUDO_CMD

chk_crt_dir $BASE_DIR

NOW=$(date +%Y%m%d%H%M%S)
DIR="${BASE_DIR}/${NOW}"
chk_crt_dir $DIR

COUNT=0
REPLY='y'
while [[ ${REPLY} =~ ^[Yy]?$ ]]; do
  COUNT=$(($COUNT + 1))

  NUM=$(printf "%03d" "${COUNT}")
  NAME="disk_${NUM}"
  DISK_DIR="${DIR}/${NAME}"
  MNT_DIR="${DISK_DIR}/mountpoint"
  FILES_DIR="${DISK_DIR}/files"
  BASE="${DISK_DIR}/${NAME}"

  chk_crt_dir "${DISK_DIR}"
  chk_crt_dir "${MNT_DIR}"
  chk_crt_dir "${FILES_DIR}"

  IMG="${BASE}.img"
  LOG="${BASE}.ddrlog"
  OUT="${BASE}.outlog"

  inf "disk ${COUNT} - id is ${NAME}"

  read -p "           enter description: "
  echo "${REPLY}" > "${BASE}.description"

  inf "    start 1st ddrescue run"
  echo "1st ddrescue run" &>> "${OUT}"
  echo "################################################################################" &>> "${OUT}"
  $SUDO ddrescue -n     "${FLOPPY_DEV}" "${IMG}" "${LOG}" &>> "${OUT}"

  inf "    start 2nd ddrescue run"
  echo "################################################################################" &>> "${OUT}"
  echo "2nd ddrescue run" &>> "${OUT}"
  echo "################################################################################" &>> "${OUT}"
  $SUDO ddrescue -d -r5 "${FLOPPY_DEV}" "${IMG}" "${LOG}" &>> "${OUT}"

  inf "    calculating hash"
  sha1sum "${IMG}" > "${BASE}.sha1"

  inf "    mounting image and retrieve files"
  $SUDO mount -t vfat -o loop -o defaults -o umask=000 -o ro "${IMG}" "${MNT_DIR}"
  ls -al "${MNT_DIR}" > "${BASE}.lsal"
  ls     "${MNT_DIR}" > "${BASE}.ls"
  echo "################################################################################" &>> "${OUT}"
  echo "rsync run" &>> "${OUT}"
  echo "################################################################################" &>> "${OUT}"
  rsync -av "${MNT_DIR}/" "${FILES_DIR}" &>> "${OUT}"
  $SUDO umount "${MNT_DIR}"

  read -p "Proceed with another disk? (Y or y for yes)" -n 1 -r
  [[ -z ${REPLY} ]] || echo ""
done



