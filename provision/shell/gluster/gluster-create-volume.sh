#!/bin/bash

#set -e

VOLNAME=$1
shift
REP=$1
shift

while true; do
  MSG="$(gluster volume status ${VOLNAME} 2>&1 1>/dev/null)"
  RET=$?
  [ $RET -eq 0 ] && break
  [ "${MSG}" != "${MSG#Another transaction is in progress}" ] || break
  sleep 1
done

[ $RET -eq 0 ] && {
  echo "gluster volume ${VOLNAME} already exists and is active."
  exit 0
}

[ "$MSG" = "Volume ${VOLNAME} does not exist" ] && {
  echo "Creating gluster volume ${VOLNAME}."
  echo "cmd: gluster volume create $VOLNAME rep $REP transport tcp $@"
  while true; do
    MSG=$(gluster volume create $VOLNAME rep $REP transport tcp $@ 2>&1 1>/dev/null)
    RET=$?
    [ $RET -eq 0 ] && break
    [ "$MSG" = "volume create: ${VOLNAME}: failed: Volume ${VOLNAME} already exists" ] && {
      RET=0
      break
    }
    [ "${MSG}" != "${MSG#Another transaction is in progress}" ] || break
  done

  [ $RET -eq 0 ] || {
    echo "gluster volume create $VOLNAME failed ('$MSG')- trying to force."

    while true; do
      MSG=$(gluster volume create $VOLNAME rep $REP transport tcp $@ force 2>&1 1>/dev/null)
      RET=$?
      [ $RET -eq 0 ] && break
      [ "$MSG" = "volume create: ${VOLNAME}: failed: Volume ${VOLNAME} already exists" ] && {
        RET=0
        break
      }
      [ "${MSG}" != "${MSG#Another transaction is in progress}" ] || break
    done
  }

  [ $RET -eq 0 ] || {
    echo "gluster volume create $VOLNAME failed with force ('$MSG')- giving up"
    exit 1
  }

  while true; do
    MSG="$(gluster volume status ${VOLNAME} 2>&1 1>/dev/null)"
    RET=$?
    [ $RET -eq 0 ] && break
    [ "${MSG}" != "${MSG#Another transaction is in progress}" ] || break
    sleep 1
  done

  [ $RET -eq 0 ] && {
    echo "gluster volume ${VOLNAME} is already started."
    exit 0
  }
}

[ "$MSG" = "Volume ${VOLNAME} is not started" ] && {
  echo "starting gluster volume ${VOLNAME}."
  while true; do
    MSG=$(gluster volume start ${VOLNAME} 2>&1 1> /dev/null)
    RET=$?
    [ $RET -eq 0 ] && break
    [ "$MSG" = "volume start: ${VOLNAME}: failed: Volume ${VOLNAME} already started" ] && {
      RET=0
      break
    }
    [ "${MSG}" != "${MSG#Another transaction is in progress}" ] || break
  done

  [ $RET -eq 0 ] || {
    echo "gluster volume start ${VOLNAME} failed ('$MSG')."
    exit 1
  }
} || {
  echo "Error: 'gluster volume status ${VOLNAME}' gave '$MSG' ($RET)"
  exit 1
}

exit 0
