#!/bin/bash

dirsearchWordlist=../wordlist/top1000.txt
dirsearchThreads=10

# input with socket addresses scheme file
fuzz(){
    echo "Start directory bruteforce using ffuf..."
    iterator=1
    while read subdomain; do
      # -c stands for colorized, -s for silent mode
      ffuf -c -u ${subdomain}/FUZZ -p 0.1-2.0 -recursion -recursion-depth 2 -mc all -fc 300,301,302,303,304,400,403,404,500,501,502,503 -fs 0 \
          -w $dirsearchWordlist -t $dirsearchThreads \
          -o $TARGETDIR/ffuf/${iterator}.html  -of html > /dev/null
      iterator=$((iterator+1))
    done < $1
}

fuzz $1
