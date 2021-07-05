#!/bin/bash

brokenfunc(){
  sleep 555 &
  echo "https://hackerone.com" | nuclei -silents -t $HOMEDIR/nuclei-templates/technologies/
}

recon(){
  CPID=$$
  echo "func PID = $CPID"
  brokenfunc &
  tmpdemopid=$!
  wait $tmpdemopid
  echo "func PID=$tmpdemopid"
}

main() {
  MAINPID=$$
  echo "[main] PID = $MAINPID"
  recon
  echo "[main] exit point PID=$MAINPID"
}

main
