#!/bin/bash

# Invoke with sudo because of masscan/nmap

# Config
altdnsWordlist=./lazyWordLists/altdns_wordlist_uniq.txt # used for permutations (--alt option required)

dirsearchWordlist=./lazyWordLists/fuzz-Bo0oM_top1000.txt # used in directory bruteforcing (--brute option)
dirsearchThreads=500

miniResolvers=./resolvers/mini_resolvers.txt

# used in hydra attack: too much words required up to 6 hours, use preferred list if possible
# sort -u ../SecLists/Usernames/top-usernames-shortlist.txt ../SecLists/Usernames/cirt-default-usernames.txt ../SecLists/Usernames/mssql-usernames-nansh0u-guardicore.txt ./wordlist/users.txt -o wordlist/users.txt
usersList=./wordlist/users.txt
# sort -u ../SecLists/Passwords/clarkson-university-82.txt ../SecLists/Passwords/cirt-default-passwords.txt ../SecLists/Passwords/darkweb2017-top100.txt ../SecLists/Passwords/probable-v2-top207.txt ./wordlist/passwords.txt -o wordlist/passwords.txt
passwordsList=./wordlist/top-20-common-SSH-passwords.txt


# optional positional arguments
brute= # enable directory bruteforce
mad= # if you sad about subdomains count, call it
alt= # permutate and alterate subdomains
wildcard= # fight against multi-level wildcard DNS to avoid false-positive results while subdomain resolves

# definitions
enumeratesubdomains(){
  echo "Enumerating all known domains using:"

  # Passive subdomain enumeration
  echo "subfinder..."
  subfinder -d $1 -silent -o ./$1/$foldername/subfinder-list.txt
  echo "assetfinder..."
  assetfinder --subs-only $1 > ./$1/$foldername/assetfinder-list.txt

  echo "github-subdomains.py..."
  github-subdomains -d $1 > ./$1/$foldername/github-subdomains-list.txt

  # remove all lines start with *-asterix
  sed -i '' '/^*/d' ./$1/$foldername/assetfinder-list.txt
  # echo "amass..."
  # amass enum --passive -log ./$1/$foldername/amass_errors.log -d $1 -o ./$1/$foldername/amass-list.txt

  # sort enumerated subdomains
  sort -u ./$1/$foldername/subfinder-list.txt ./$1/$foldername/assetfinder-list.txt ./$1/$foldername/github-subdomains-list.txt -o ./$1/$foldername/enumerated-subdomains.txt
  sed -i '' '/^[.]/d' ./$1/$foldername/enumerated-subdomains.txt

}

checkwaybackurls(){
  if [ "$mad" = "1" ]; then
    echo "gau..."
    # gau -subs mean include subdomains
    cat ./$1/$foldername/enumerated-subdomains.txt | gau -subs -o ./$1/$foldername/gau_output.txt
    echo "waybackurls..."
    cat ./$1/$foldername/enumerated-subdomains.txt | waybackurls > ./$1/$foldername/waybackurls_output.txt
    echo "github-endpoints.py..."
    github-endpoints -d $1 > ./$1/$foldername/github-endpoints_out.txt

    # wayback_output.txt needs for checkparams
    sort -u ./$1/$foldername/gau_output.txt ./$1/$foldername/waybackurls_output.txt ./$1/$foldername/github-endpoints_out.txt -o ./$1/$foldername/wayback_output.txt
    sed -i '' '/web.archive.org/d' ./$1/$foldername/wayback_output.txt
    cat ./$1/$foldername/wayback_output.txt | unfurl --unique domains > ./$1/$foldername/wayback-subdomains-list.txt
    sed -i '' '/[.]$/d' ./$1/$foldername/wayback-subdomains-list.txt
    # only paths, see https://github.com/tomnomnom/unfurl
    cat ./$1/$foldername/wayback_output.txt | unfurl paths | sed 's/\///' | sort | uniq > ./$1/$foldername/wayback_paths_list.txt
    # full paths+queries
    cat ./$1/$foldername/wayback_output.txt | unfurl format '%p%?%q' | sed 's/\///' | sort | uniq > ./$1/$foldername/wayback_paths_query_list.txt

    sort -u ./$1/$foldername/wayback_paths_list.txt ./$1/$foldername/wayback_paths_query_list.txt -o ./$1/$foldername/wayback_params_list.txt
    sed -i '' '/[.]$/d' ./$1/$foldername/wayback_params_list.txt
  fi
  if [ "$alt" = "1" -a "$mad" = "1" ]; then
    # prepare target specific subdomains wordlist to gain more subdomains using --mad mode
    cat ./$1/$foldername/wayback_output.txt | unfurl format %S | sort | uniq > ./$1/$foldername/wayback-subdomains-wordlist.txt
    sort -u $altdnsWordlist ./$1/$foldername/wayback-subdomains-wordlist.txt -o $customSubdomainsWordList
  fi
}

sortsubdomains(){
  sort -u ./$1/$foldername/enumerated-subdomains.txt ./$1/$foldername/wayback-subdomains-list.txt -o ./$1/$foldername/1-real-subdomains.txt
  cp ./$1/$foldername/1-real-subdomains.txt ./$1/$foldername/2-all-subdomains.txt
}

permutatesubdomains(){
  if [ "$alt" = "1" ]; then
    mkdir ./$1/$foldername/alterated/
    echo "altdns..."
    altdns -i ./$1/$foldername/1-real-subdomains.txt -o ./$1/$foldername/alterated/altdns_out.txt -w $customSubdomainsWordList
    sed -i '' '/^[.]/d;/^[-]/d;/\.\./d' ./$1/$foldername/alterated/altdns_out.txt

    echo "dnsgen..."
    dnsgen -f ./$1/$foldername/1-real-subdomains.txt -w $customSubdomainsWordList > ./$1/$foldername/alterated/dnsgen_out.txt
    sed -i '' '/^[.]/d;/^[-]/d;/\.\./d' ./$1/$foldername/alterated/dnsgen_out.txt
    sed -i '' '/^[-]/d' ./$1/$foldername/alterated/dnsgen_out.txt

    # combine permutated domains and exclude out of scope domains
    SCOPE=$1
    echo "SCOPE=$SCOPE"
    grep -h "[.]${SCOPE}$" ./$1/$foldername/alterated/* | sort | uniq > ./$1/$foldername/alterated/permutated-list.txt

    sort -u ./$1/$foldername/1-real-subdomains.txt ./$1/$foldername/alterated/permutated-list.txt -o ./$1/$foldername/2-all-subdomains.txt
  fi
}

# check live subdomains
# wildcard check like: `dig @188.93.60.15 A,CNAME {test123,0000}.$domain +short`
# shuffledns uses for wildcard because massdn can't
dnsprobing(){
  if [ "$wildcard" = "1" ]; then
    echo "[shuffledns] massdns probing with wildcard sieving..."
    shuffledns -silent -d $1 -list ./$1/$foldername/2-all-subdomains.txt -retries 1 -r $miniResolvers -o ./$1/$foldername/shuffledns-list.txt
    # additional resolving because shuffledns missing IP on output
    echo "[dnsx] dnsprobing..."
    # echo "[dnsx] wildcard filtering:"
    # dnsx -l ./$1/$foldername/shuffledns-list.txt -wd $1 -o ./$1/$foldername/dnsprobe_live.txt
    echo "[dnsx] getting hostnames and its A records:"
    # -t mean cuncurrency
    dnsx -t 350 -a -resp -r $miniResolvers -l ./$1/$foldername/shuffledns-list.txt -o ./$1/$foldername/dnsprobe_out.txt
    # clear file from [ and ] symbols
    tr -d '\[\]' < ./$1/$foldername/dnsprobe_out.txt > ./$1/$foldername/dnsprobe_output_tmp.txt
    # split resolved hosts ans its IP (for masscan)
    cut -f1 -d ' ' ./$1/$foldername/dnsprobe_output_tmp.txt | sort | uniq > ./$1/$foldername/dnsprobe_subdomains.txt
    cut -f2 -d ' ' ./$1/$foldername/dnsprobe_output_tmp.txt | sort | uniq > ./$1/$foldername/dnsprobe_ip.txt
  else
    echo "[massdns] dnsprobing..."
    # pure massdns:
    massdns -q -r $miniResolvers -o S -w ./$1/$foldername/massdns_output.txt ./$1/$foldername/2-all-subdomains.txt
    # 
    sed -i '' '/CNAME/d' ./$1/$foldername/massdns_output.txt
    cut -f1 -d ' ' ./$1/$foldername/massdns_output.txt | sed 's/.$//' | sort | uniq > ./$1/$foldername/dnsprobe_subdomains.txt
    cut -f3 -d ' ' ./$1/$foldername/massdns_output.txt | sort | uniq > ./$1/$foldername/dnsprobe_ip.txt
  fi
}

checkhttprobe(){
  echo "[httpx] Starting httpx probe testing..."
  # resolve IP and hosts with http|https for nuclei, gospider and ffuf-bruteforce
  httpx -l ./$1/$foldername/dnsprobe_ip.txt -silent -follow-host-redirects -fc 300,301,302,303 -threads 500 -o ./$1/$foldername/httpx_output_1.txt
  httpx -l ./$1/$foldername/dnsprobe_subdomains.txt -silent -follow-host-redirects -fc 300,301,302,303 -threads 500 -o ./$1/$foldername/httpx_output_2.txt

  sort -u ./$1/$foldername/httpx_output_1.txt ./$1/$foldername/httpx_output_2.txt -o ./$1/$foldername/3-all-subdomain-live-scheme.txt
}

nucleitest(){
  if [ ! -e ./$1/$foldername/3-all-subdomain-live-scheme.txt ]; then
    echo "[nuclei] There is no live hosts. exit 1"
    exit 1
  fi
  echo "[nuclei] CVE testing..."
  # -c maximum templates processed in parallel
  nuclei -silent -l ./$1/$foldername/3-all-subdomain-live-scheme.txt -t ../nuclei-templates/technologies/s3-detect.yaml -t ../nuclei-templates/subdomain-takeover/ -t ../nuclei-templates/generic-detections/ -t ../nuclei-templates/vulnerabilities/ -t ../nuclei-templates/security-misconfiguration/ -t ../nuclei-templates/cves/ -t ../nuclei-templates/misc/ -t ../nuclei-templates/files/ -exclude ../nuclei-templates/misc/missing-csp.yaml -exclude ../nuclei-templates/misc/missing-x-frame-options.yaml -exclude ../nuclei-templates/misc/missing-hsts.yaml -o ./$1/$foldername/nuclei_output.txt
}

gospidertest(){
  echo "[gospider] Web crawling..."
  gospider -S ./$1/$foldername/3-all-subdomain-live-scheme.txt --no-redirect --timeout 4 -o ./$1/$foldername/gospider -c 40 -t 40
}

hakrawlercrawling(){
  echo "[hakrawler] Web crawling..."
  cat ./$1/$foldername/1-real-subdomains.txt | hakrawler -plain -insecure -depth 3 > ./$1/$foldername/hakrawler_out.txt
}

sqlmaptest(){
  if [ "$mad" = "1" ]; then
    gospidertest $1
    hakrawlercrawling $1
    # prepare list of the php urls from wayback, hakrawler and gospider
    echo "[sqlmap] wayback sqlist..."
    grep -e 'php?[[:alnum:]]*=' -e 'asp?[[:alnum:]]*=' -e '\*$' ./$1/$foldername/wayback_output.txt | sort | uniq > ./$1/$foldername/wayback_sqli_list.txt

    # -h means Never print filename headers
    echo "[sqlmap] gospider sqlist..."
    grep -h '\[url\]' ./$1/$foldername/gospider/* | cut -f5 -d ' ' | grep -e 'php?[[:alnum:]]*=' -e 'asp?[[:alnum:]]*=' -e '\*$' | sort | uniq > ./$1/$foldername/gospider_sqli_list.txt
    grep -h 'linkfinder' ./$1/$foldername/gospider/* | cut -f3 -d ' ' | grep -e 'php?[[:alnum:]]*=' -e 'asp?[[:alnum:]]*=' -e '\*$' | sort | uniq >> ./$1/$foldername/gospider_sqli_list.txt

    echo "[sqlmap] hakrawler sqlist..."
    grep -e '\[url\]' -e '\[form\]' ./$1/$foldername/hakrawler_out.txt | cut -f2 -d ' ' | grep -e 'php?[[:alnum:]]*=' -e 'asp?[[:alnum:]]*=' -e '\*$' | sort | uniq > ./$1/$foldername/hakrawler_sqli_list.txt

    sort -u ./$1/$foldername/wayback_sqli_list.txt ./$1/$foldername/gospider_sqli_list.txt ./$1/$foldername/hakrawler_sqli_list.txt -o ./$1/$foldername/sqli_list.txt
    # perform the sqlmap
    echo "[sqlmap.py] SQLi testing..."
    sqlmap -m ./$1/$foldername/sqli_list.txt --batch --random-agent --output-dir=./$1/$foldername/sqlmap/
  fi
}

smugglertest(){
  echo "[smuggler.py] Try to find request smuggling vulnerabilities..."
  smuggler -u ./$1/$foldername/3-all-subdomain-live-scheme.txt

  # check for VULNURABLE keyword
  if [ -s ./smuggler/output ]; then
    cat ./smuggler/output | grep 'VULNERABLE' > ./$1/$foldername/smugglinghosts.txt
    if [ -s ./$1/$foldername/smugglinghosts.txt ]; then
      echo "Smuggling vulnerability found under the next hosts:"
      echo
      cat ./$1/$foldername/smugglinghosts.txt | grep 'VULN'
    else
      echo "There are no Request Smuggling host found"
    fi
  else
    echo "smuggler doesn\'t provide the output, check it issue!"
  fi
}

# nmap(){
#   echo "[phase 7] Test for unexpected open ports..."
#   nmap -sS -PN -T4 --script='http-title' -oG nmap_output_og.txt
# }
masscantest(){
  echo "[masscan] Looking for open ports..."
  # max-rate for accuracy
  # 25/587-smtp, 110/995-pop3, 143/993-imap, 445-smb, 3306-mysql, 3389-rdp, 5432-postgres, 5900/5901-vnc, 27017-mongodb
  # masscan -p21,22,23,25,53,80,110,113,587,995,3306,3389,5432,5900,8080,27017 -iL ./$1/$foldername/dnsprobe_ip.txt --rate 1000 --open-only -oG ./$1/$foldername/masscan_output.gnmap
  masscan -p1-65535 -iL ./$1/$foldername/dnsprobe_ip.txt --rate 1000 --open-only -oG ./$1/$foldername/masscan_output.gnmap
  sed -i '' '1d;2d;$d' ./$1/$foldername/masscan_output.gnmap # remove 1,2 and last lines from masscan out file
}

#  NSE-approach
# nmap --script "discovery,ftp*,ssh*,http-vuln*,mysql-vuln*,imap-*,pop3-*" -iL ./$1/$foldername/nmap_input.txt
nmap_nse(){
  # https://gist.github.com/storenth/b419dc17d2168257b37aa075b7dd3399
  # https://youtu.be/La3iWKRX-tE?t=1200
  # https://medium.com/@noobhax/my-recon-process-dns-enumeration-d0e288f81a8a
  echo "$[nmap] scanning..."
  while read line; do
    IP=$(echo $line | awk '{ print $4 }')
    PORT=$(echo $line | awk -F '[/ ]+' '{print $7}')
    FILENAME=$(echo $line | awk -v PORT=$PORT '{ print "nmap_"PORT"_"$4}' )

    echo "[nmap] scanning $IP using $PORT port"
    # -n: no DNS resolution
    # -Pn: Treat all hosts as online - skip host discovery
    # -sV: Probe open ports to determine service/version info (--version-intensity 9: means maximum probes)
    # -sS: raw packages
    # -sC: equivalent to --script=default (-O and -sC equal to run with -A)
    nmap -n -O -sC -sV --version-intensity 9 -sS --max-rate 500 -Pn -T3 -p$PORT -oG ./$1/$foldername/nmap/$FILENAME $IP
    echo
    echo
    sleep 1
  done < ./$1/$foldername/masscan_output.gnmap
}

# hydra user/password attack on popular protocols
hydratest(){
  echo "[hydra] attacking network protocols"
  while read line; do
    IP=$(echo $line | awk '{ print $4 }')
    PORT=$(echo $line | awk -F '[/ ]+' '{print $7}')
    PROTOCOL=$(echo $line | awk -F '[/ ]+' '{print $10}')
    FILENAME=$(echo $line | awk -v PORT=$PORT '{ print "hydra_"PORT"_"$4}' )

    echo "[hydra] scanning $IP on $PORT port using $PROTOCOL protocol"

    hydra -o ./$1/$foldername/hydra/$FILENAME -b text -L $usersList -P $passwordsList -s $PORT $IP $PROTOCOL

  done < ./$1/$foldername/masscan_output.gnmap
}

# prepare custom wordlist for directory bruteforce using --mad and --brute mode only
checkparams(){
  if [ "$brute" = "1" -a "$mad" = "1" ]; then
    echo "Prepare custom wordlist"
    # merge base dirsearchWordlist with target-specific list for deep dive (time sensitive)
    sort -u ./$1/$foldername/wayback_params_list.txt $dirsearchWordlist -o $customFfufWordList
    sudo sed -i '' '/^[[:space:]]*$/d' $customFfufWordList
  fi
}

ffufbrute(){
  if [ "$brute" = "1" ]; then
    echo "Start directory bruteforce using ffuf..."
    iterator=1
    while read subdomain; do
      # -c stands for colorized, -s for silent mode
      ffuf -c -s -u ${subdomain}/FUZZ -recursion -recursion-depth 3 -mc all -fc 300,301,302,303,304,400,403,404,500,501,502,503 -w $customFfufWordList -t $dirsearchThreads -o ./$1/$foldername/ffuf/${iterator}.csv -of csv
      iterator=$((iterator+1))
    done < ./$1/$foldername/3-all-subdomain-live-scheme.txt
  fi
}

recon(){
  enumeratesubdomains $1
  checkwaybackurls $1
  sortsubdomains $1
  permutatesubdomains $1

  dnsprobing $1
  checkhttprobe $1
  nucleitest $1

  sqlmaptest $1
  smugglertest $1

  masscantest $1
  nmap_nse $1
  # hydratest $1

  checkparams $1
  ffufbrute $1

  # echo "Generating HTML-report here..."
  echo "Lazy done."
}


main(){
  if [ -d "./$1" ]
  then
    echo "This is a known target."
  else
    mkdir ./$1
  fi
  if [ -s ./smuggler/output ]; then
    rm ./smuggler/output
  fi

  mkdir ./$1/$foldername

  # used for ffuf bruteforce
  touch ./$1/$foldername/custom_ffuf_wordlist.txt
  customFfufWordList=./$1/$foldername/custom_ffuf_wordlist.txt
  cp $dirsearchWordlist $customFfufWordList
  # used to save target specific list for alterations (shuffledns, altdns)
  # if [ "$mad" = "1" ]; then
  #   altdnsWordlist=./lazyWordLists/altdns_wordlist.txt
  # else
  #   altdnsWordlist=./lazyWordLists/altdns_wordlist_uniq.txt
  # fi
  touch ./$1/$foldername/custom_subdomains_wordlist.txt
  customSubdomainsWordList=./$1/$foldername/custom_subdomains_wordlist.txt
  cp $altdnsWordlist $customSubdomainsWordList

  if [ "$brute" = "1" ]; then
    # ffuf dir uses to store brute output
    mkdir ./$1/$foldername/ffuf/
  fi

  # nmap output
  mkdir ./$1/$foldername/nmap/
  # hydra output
  # mkdir ./$1/$foldername/hydra/
  if [ "$mad" = "1" ]; then
    # gospider output
    mkdir ./$1/$foldername/gospider/
    # sqlmap output
    mkdir ./$1/$foldername/sqlmap/
  fi
  # brutespray output
  # mkdir ./$1/$foldername/brutespray/
  # subfinder list of subdomains
  touch ./$1/$foldername/subfinder-list.txt 
  # assetfinder list of subdomains
  touch ./$1/$foldername/assetfinder-list.txt
  # amass list of subdomains
  # touch ./$1/$foldername/amass-list.txt
  # shuffledns list of subdomains
  touch ./$1/$foldername/shuffledns-list.txt
  # gau/waybackurls list of subdomains
  touch ./$1/$foldername/wayback-subdomains-list.txt
  # gau list of only params
  touch ./$1/$foldername/wayback_params_list.txt

  # mkdir ./$1/$foldername/reports/
  # echo "Reports goes to: ./${1}/${foldername}"

    recon $1
    # master_report $1
}

usage(){
  echo "Usage: $FUNCNAME <target> [[-b] | [--brute]] [[-m] | [--mad]]"
  echo "Example: $FUNCNAME example.com --mad"
}

invokation(){
  echo "Warn: unexpected positional argument: $1"
  echo "$(basename $0) [[-h] | [--help]]"
}

# check for help arguments or exit with no arguments
checkhelp(){
  while [ "$1" != "" ]; do
      case $1 in
          -h | --help )           usage
                                  exit
                                  ;;
          # * )                     invokation "$@"
          #                         exit 1
      esac
      shift
  done
}

# check for specifiec arguments (help)
checkargs(){
  while [ "$1" != "" ]; do
      case $1 in
          -b | --brute )          brute="1"
                                  ;;
          -m | --mad )            mad="1"
                                  ;;
          -a | --alt )            alt="1"
                                  ;;
          -w | --wildcard )       wildcard="1"
                                  ;;
          # * )                     invokation $1
          #                         exit 1
      esac
      shift
  done
}


##### Main

if [ $# -eq 0 ]; then
    echo "Error: expected positional arguments"
    usage
    exit 1
else
  if [ $# -eq 1 ]; then
    checkhelp "$@"
  fi
fi

if [ $# -gt 1 ]; then
  checkargs "$@"
fi

# positional parameters test
echo "Check params: $@"
echo "Check # of params: $#"
echo "Check params \$1: $1"
echo "Check params \$brute: $brute"
echo "Check params \$mad: $mad"
echo "Check params \$alt: $alt"
echo "Check params \$wildcard: $wildcard"

./logo.sh
path=$(pwd)
# to avoid cleanup or `sort -u` operation
foldername=recon-$(date +"%y-%m-%d_%H-%M-%S")

# invoke
main $1
