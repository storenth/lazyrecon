#!/bin/bash
set -eE
set -m

# Invoke with sudo because of masscan/nmap

#import the config
#https://stackoverflow.com/questions/5228345/how-to-reference-a-file-for-variables-using-bash
. lazyconfig

# https://golang.org/doc/install#install
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$HOME/go/bin:$HOMEDIR/go/bin

# background PID's control
PID_SUBFINDER_FIRST=
PID_ASSETFINDER=
PID_GAU=
PID_WAYBACK=
SERVER_PID=
PID_SCREEN=
PID_NUCLEI=
PID_HTTPX=


[ -d "$STORAGEDIR" ] || mkdir -p $STORAGEDIR

# Use sed properly
SEDOPTION=(-i)
if [[ "$OSTYPE" == "darwin"* ]]; then
  SEDOPTION=(-i '')
fi

# optional positional arguments
ip= # test for specific single IP
cidr= # test for CIDR based on ASN number, see https://bgp.he.net/
single= # if just one target in scope
list= # list of domains to test, no need wildcard support, mad mode not implemented (need to avoid --list with --mad)
wildcard= # fight against multi-level wildcard DNS to avoid false-positive results while subdomain resolves
brute= # enable directory bruteforce
fuzz= # enable parameter fuzzing (listen server is automatically deployed using https://github.com/projectdiscovery/interactsh)
mad= # if you sad about subdomains count, call it
alt= # permutate and alterate subdomains
discord= # send notifications
vps= # tune async jobs to reduce stuff like concurrent headless chromium but increase bruteforce list and enable DNS bruteforce
quiet= # quiet mode


#Verify all dependency tools work
echo "Checking tools..."
subfinder --version 2> /dev/null
interactsh-client -h 2> /dev/null
assetfinder --help 2> /dev/null
if [[ -e $HOMEDIR/github-subdomains.py ]]; then
  echo "github-subdomains.py not found!"
fi
if [[ -e $HOMEDIR/github-endpoints.py ]]; then
  echo "github-endpoints.py not found!"
fi
waybackurls --help 2> /dev/null
gau -version 1> /dev/null
altdns --help 1> /dev/null
dnsgen --help 1> /dev/null
shuffledns -version 2> /dev/null
masscan --help 1> /dev/null
dnsx -version 2> /dev/null
httpx -version 2> /dev/null
nuclei -version 2> /dev/null
if [[ -e $HOMEDIR/smuggler.py ]]; then
  echo "smuggler.py not found!"
fi
ffuf -V 1> /dev/null
hydra -help 1> /dev/null
gf --help 2> /dev/null
qsreplace --help 2> /dev/null
unfurl --help 2> /dev/null
sqlmap --help 1> /dev/null
gospider --help 1> /dev/null
hakrawler --help 2> /dev/null
if [[ -e $HOMEDIR/ssrf.py ]]; then
  echo "ssrf-headers-tool not found!"
fi
# storenth-lfi is already included in nuclei-templates
nmap --help 1> /dev/null
chromium --help 1> /dev/null
interlace --help 1> /dev/null
dnsx --version 2> /dev/null


MINIRESOLVERS=./resolvers/mini_resolvers.txt
ALTDNSWORDLIST=./lazyWordLists/altdns_wordlist_uniq.txt
BRUTEDNSWORDLIST=./wordlist/six2dez_wordlist.txt

httpxcall='httpx -silent -threads 150 -ports 80,81,300,443,591,593,832,981,1010,1311,1099,2082,2095,2096,2480,3000,3128,3333,4243,4443,4444,4567,4711,4712,4993,5000,5104,5108,5280,5281,5601,5800,6543,7000,7001,7396,7474,8000,8001,8008,8014,8042,8060,8069,8080,8081,8083,8088,8090,8091,8095,8118,8123,8172,8181,8222,8243,8280,8281,8333,8337,8443,8444,8500,8800,8834,8880,8881,8888,8983,9000,9001,9043,9060,9080,9090,9091,9200,9443,9502,9800,9981,10000,10250,11371,12443,15672,16080,17778,18091,18092,20720,32000,55440,55672 -random-agent'

# definitions
enumeratesubdomains(){
  if [ "$single" = "1" ]; then
    echo $1 > $TARGETDIR/enumerated-subdomains.txt
  elif [ "$cidr" = "1" ]; then
    mapcidr -silent -cidr $1 -o $TARGETDIR/enumerated-subdomains.txt
  elif [ "$list" = "1" ]; then
    cp $1 $TARGETDIR/enumerated-subdomains.txt
  else
    echo "Enumerating all known domains using:"

    # Passive subdomain enumeration
    echo "subfinder..."
    echo $1 >> $TARGETDIR/subfinder-list.txt # to be sure main domain added in case of one domain scope
    subfinder -all -d $1 -silent -o $TARGETDIR/subfinder-list.txt &
    PID_SUBFINDER_FIRST=$!

    echo "assetfinder..."
    assetfinder --subs-only $1 > $TARGETDIR/assetfinder-list.txt &
    PID_ASSETFINDER=$!

    echo "github-subdomains.py..."
    github-subdomains -d $1 -t $GITHUBTOKEN | sed "s/^\.//;/error/d" | grep "[.]${1}" > $TARGETDIR/github-subdomains-list.txt

    echo "wait PID_SUBFINDER_FIRST $PID_SUBFINDER_FIRST and PID_ASSETFINDER $PID_ASSETFINDER"
    wait $PID_SUBFINDER_FIRST $PID_ASSETFINDER
    echo "PID_SUBFINDER_FIRST $PID_SUBFINDER_FIRST and PID_ASSETFINDER $PID_ASSETFINDER done."
    # echo "amass..."
    # amass enum --passive -log $TARGETDIR/amass_errors.log -d $1 -o $TARGETDIR/amass-list.txt

    SCOPE=$1
    grep "[.]${SCOPE}$" $TARGETDIR/assetfinder-list.txt | sort -u -o $TARGETDIR/assetfinder-list.txt
    # remove all lines start with *-asterix and out-of-scope domains
    sed "${SEDOPTION[@]}" '/^*/d' $TARGETDIR/assetfinder-list.txt
    # sort enumerated subdomains
    sort -u "$TARGETDIR"/subfinder-list.txt $TARGETDIR/assetfinder-list.txt "$TARGETDIR"/github-subdomains-list.txt -o "$TARGETDIR"/enumerated-subdomains.txt

    if [[ -s "$TARGETDIR"/enumerated-subdomains.txt ]]; then
      sed "${SEDOPTION[@]}" '/^[.]/d' $TARGETDIR/enumerated-subdomains.txt
      if [[ -n "$alt" ]]; then
        echo
        echo "[subfinder] second try..."
        # dynamic sensor
        BAR='##############################'
        FILL='------------------------------'
        totalLines=$(wc -l "$TARGETDIR"/enumerated-subdomains.txt | awk '{print $1}')  # num. lines in file
        barLen=30
        count=0

          # --- iterate over lines in file ---
          while read line; do
              # update progress bar
              count=$(($count + 1))
              percent=$((($count * 100 / $totalLines * 100) / 100))
              i=$(($percent * $barLen / 100))
              echo -ne "\r[${BAR:0:$i}${FILL:$i:barLen}] $count/$totalLines ($percent%)"
              subfinder -silent -d $line >> "${TARGETDIR}"/subfinder-list-2.txt
          done < "${TARGETDIR}"/enumerated-subdomains.txt

        sort -u "$TARGETDIR"/enumerated-subdomains.txt "$TARGETDIR"/subfinder-list-2.txt -o "$TARGETDIR"/enumerated-subdomains.txt

        < $TARGETDIR/enumerated-subdomains.txt unfurl format %S | sort | uniq > $TARGETDIR/tmp/enumerated-subdomains-wordlist.txt
        sort -u $ALTDNSWORDLIST $TARGETDIR/tmp/enumerated-subdomains-wordlist.txt -o $customSubdomainsWordList
      fi
    else 
      echo "No target was found!"
      error_handler
    fi
  fi
}

getwaybackurl(){
  echo "waybackurls..."
  < $TARGETDIR/enumerated-subdomains.txt waybackurls | sort | uniq | grep "[.]${1}" | qsreplace -a > $TARGETDIR/tmp/waybackurls_output.txt
  echo "waybackurls done."
}
getgau(){
  echo "gau..."
  SUBS=""
  if [[ -n "$wildcard" ]]; then
    SUBS="-subs"
  fi
  # gau -subs mean include subdomains
  < $TARGETDIR/enumerated-subdomains.txt gau $SUBS | sort | uniq | grep "[.]${1}" | qsreplace -a > $TARGETDIR/tmp/gau_output.txt
  echo "gau done."
}
getgithubendpoints(){
  echo "github-endpoints.py..."
  github-endpoints -d $1 -t $GITHUBTOKEN | sort | uniq | grep "[.]${1}" | qsreplace -a > $TARGETDIR/tmp/github-endpoints_out.txt
  echo "github-endpoints done."
}

checkwaybackurls(){
  SCOPE=$1

  getgau $1 &
  PID_GAU=$!

  getwaybackurl $1 &
  PID_WAYBACK=$!

  getgithubendpoints $1

  wait $PID_GAU $PID_WAYBACK

  sort -u $TARGETDIR/tmp/gau_output.txt $TARGETDIR/tmp/waybackurls_output.txt $TARGETDIR/tmp/github-endpoints_out.txt -o $TARGETDIR/wayback/wayback_output.txt

  # need to get some extras subdomains
  < $TARGETDIR/wayback/wayback_output.txt unfurl --unique domains | sed '/web.archive.org/d;/*.${1}/d' > $TARGETDIR/wayback-subdomains-list.txt

  if [[ -n "$alt" && -n "$wildcard" ]]; then
    # prepare target specific subdomains wordlist to gain more subdomains using --mad mode
    < $TARGETDIR/wayback/wayback_output.txt unfurl format %S | sort | uniq > $TARGETDIR/wayback-subdomains-wordlist.txt
    sort -u $customSubdomainsWordList $TARGETDIR/wayback-subdomains-wordlist.txt -o $customSubdomainsWordList
  fi
}

sortsubdomains(){
  sort -u $TARGETDIR/enumerated-subdomains.txt $TARGETDIR/wayback-subdomains-list.txt -o $TARGETDIR/1-real-subdomains.txt
  cp $TARGETDIR/1-real-subdomains.txt $TARGETDIR/2-all-subdomains.txt
}

dnsbruteforcing(){
  if [[  -n "$wildcard" && -n "$vps" ]]; then
    echo "puredns bruteforce..."
    # https://sidxparab.gitbook.io/subdomain-enumeration-guide/active-enumeration/dns-bruteforcing
    puredns bruteforce $BRUTEDNSWORDLIST $1 -r $MINIRESOLVERS --wildcard-batch 100000 -l 5000 -q | tee $TARGETDIR/purebruteforce.txt >> $TARGETDIR/1-real-subdomains.txt
    sort -u $TARGETDIR/1-real-subdomains.txt -o $TARGETDIR/1-real-subdomains.txt
  fi
}

permutatesubdomains(){
  if [[ -n "$alt" && -n "$wildcard" && -n "$vps" ]]; then
    echo "dnsgen..."
    dnsgen $TARGETDIR/1-real-subdomains.txt -w $customSubdomainsWordList > $TARGETDIR/tmp/dnsgen_out.txt
    sed "${SEDOPTION[@]}" '/^[.]/d;/^[-]/d;/\.\./d' $TARGETDIR/tmp/dnsgen_out.txt

    sort -u $TARGETDIR/1-real-subdomains.txt $TARGETDIR/tmp/dnsgen_out.txt -o $TARGETDIR/2-all-subdomains.txt
  fi
}

# check live subdomains
# wildcard check like: `dig @188.93.60.15 A,CNAME {test123,0000}.$domain +short`
# puredns/shuffledns uses for wildcard sieving because massdns can't
dnsprobing(){
  echo
  # check we test hostname or IP
  if [[ -n "$ip" ]]; then
    echo
    echo "[dnsx] try to get PTR records"
    echo $1 > $TARGETDIR/dnsprobe_ip.txt
    echo $1 | dnsx -silent -ptr -resp-only -o $TARGETDIR/dnsprobe_subdomains.txt # also try to get subdomains
  elif [[ -n "$cidr" ]]; then
    echo "[dnsx] try to get PTR records"
    cp  $TARGETDIR/enumerated-subdomains.txt $TARGETDIR/dnsprobe_ip.txt
    dnsx -silent -ptr -resp-only -r $MINIRESOLVERS -l $TARGETDIR/dnsprobe_ip.txt -o $TARGETDIR/dnsprobe_subdomains.txt # also try to get subdomains
  elif [[ -n "$single" ]]; then
    echo $1 | dnsx -silent -a -resp-only -o $TARGETDIR/dnsprobe_ip.txt
    echo $1 > $TARGETDIR/dnsprobe_subdomains.txt
  elif [[ -n "$list" ]]; then
      echo "[massdns] probing and wildcard sieving..."
      # shuffledns -silent -list $TARGETDIR/2-all-subdomains.txt -retries 1 -r $MINIRESOLVERS -o $TARGETDIR/shuffledns-list.txt
      puredns -r $MINIRESOLVERS resolve $TARGETDIR/2-all-subdomains.txt --wildcard-batch 100000 -l 5000 -w $TARGETDIR/resolved-list.txt
      # # additional resolving because shuffledns/pureDNS missing IP on output
      echo
      echo "[dnsx] getting hostnames and its A records:"
      # -t mean cuncurrency
      dnsx -silent -t 250 -a -resp -r $MINIRESOLVERS -l $TARGETDIR/resolved-list.txt -o $TARGETDIR/dnsprobe_out.txt
      # clear file from [ and ] symbols
      tr -d '\[\]' < $TARGETDIR/dnsprobe_out.txt > $TARGETDIR/dnsprobe_output_tmp.txt
      # split resolved hosts ans its IP (for masscan)
      cut -f1 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_subdomains.txt
      cut -f2 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_ip.txt
  else
      echo "[puredns] massdns probing with wildcard sieving..."
      puredns -r $MINIRESOLVERS resolve $TARGETDIR/2-all-subdomains.txt --wildcard-batch 100000 -l 5000 -w $TARGETDIR/resolved-list.txt
      # shuffledns -silent -d $1 -list $TARGETDIR/2-all-subdomains.txt -retries 5 -r $MINIRESOLVERS -o $TARGETDIR/shuffledns-list.txt
      # additional resolving because shuffledns missing IP on output
      echo
      echo "[dnsx] getting hostnames and its A records:"
      # -t mean cuncurrency
      dnsx -silent -t 250 -a -resp -r $MINIRESOLVERS -l $TARGETDIR/resolved-list.txt -o $TARGETDIR/dnsprobe_out.txt

      # clear file from [ and ] symbols
      tr -d '\[\]' < $TARGETDIR/dnsprobe_out.txt > $TARGETDIR/dnsprobe_output_tmp.txt
      # split resolved hosts ans its IP (for masscan)
      cut -f1 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_subdomains.txt
      cut -f2 -d ' ' $TARGETDIR/dnsprobe_output_tmp.txt | sort | uniq > $TARGETDIR/dnsprobe_ip.txt
  fi
  echo "[dnsx] done."
}

checkhttprobe(){
  echo
  echo "[httpx] Starting http probe testing..."
  # resolve IP and hosts using socket address style for chromium, nuclei, gospider, ssrf, lfi and bruteforce
  if [[ -n "$ip" || -n "$cidr" ]]; then
    echo "[httpx] IP probe testing..."
    $httpxcall -l $TARGETDIR/dnsprobe_ip.txt -o $TARGETDIR/3-all-subdomain-live-scheme.txt
    $httpxcall -l $TARGETDIR/dnsprobe_subdomains.txt >> $TARGETDIR/3-all-subdomain-live-scheme.txt
  else
    $httpxcall -l $TARGETDIR/dnsprobe_subdomains.txt -o $TARGETDIR/3-all-subdomain-live-scheme.txt
    $httpxcall -l $TARGETDIR/dnsprobe_ip.txt >> $TARGETDIR/3-all-subdomain-live-scheme.txt

      if [[ ( -n "$alt" || -n "$vps" ) && -s "$TARGETDIR"/dnsprobe_ip.txt ]]; then
        echo
        echo "finding math mode of the IP numbers"
        MODEOCTET=$(cut -f1 -d '.' $TARGETDIR/dnsprobe_ip.txt | sort -n | uniq -c | sort | tail -n1 | xargs)
        ISMODEOCTET1=$(echo $MODEOCTET | awk '{ print $1 }')
        if ((ISMODEOCTET1 > 1)); then
          MODEOCTET1=$(echo $MODEOCTET | awk '{ print $2 }')

          MODEOCTET=$(grep "^${MODEOCTET1}" $TARGETDIR/dnsprobe_ip.txt | cut -f2 -d '.' | sort -n | uniq -c | sort | tail -n1 | xargs)
          ISMODEOCTET2=$(echo $MODEOCTET | awk '{ print $1 }')
          if ((ISMODEOCTET2 > 1)); then
            MODEOCTET2=$(echo $MODEOCTET | awk '{ print $2 }')
            CIDR1="${MODEOCTET1}.${MODEOCTET2}.0.0/16"
            echo "mode found: $CIDR1"
            # look at https://github.com/projectdiscovery/dnsx/issues/34 to add `-wd` support here
            mapcidr -silent -cidr $CIDR1 | dnsx -silent -resp-only -ptr | grep $1 | sort | uniq | tee $TARGETDIR/dnsprobe_ptr.txt | \
                puredns -q -r $MINIRESOLVERS resolve --wildcard-batch 100000 -l 5000 | \
                dnsx -silent -r $MINIRESOLVERS -a -resp-only | tee -a $TARGETDIR/dnsprobe_ip.txt | tee $TARGETDIR/dnsprobe_ip_mode.txt | \
                $httpxcall >> $TARGETDIR/3-all-subdomain-live-scheme.txt

            # sort new assets
            sort -u $TARGETDIR/dnsprobe_ip.txt  -o $TARGETDIR/dnsprobe_ip.txt 

          fi
        fi
        echo "finding math mode done."
      fi
  fi

  # sort -u $TARGETDIR/httpx_output_1.txt $TARGETDIR/httpx_output_2.txt -o $TARGETDIR/3-all-subdomain-live-scheme.txt
  < $TARGETDIR/3-all-subdomain-live-scheme.txt unfurl format '%d:%P' > $TARGETDIR/3-all-subdomain-live-socket.txt
  echo "[httpx] done."
}

gospidertest(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    SCOPE=$1
    echo
    echo "[gospider] Web crawling..."
    gospider -q -r -S $TARGETDIR/3-all-subdomain-live-scheme.txt --timeout 7 -o $TARGETDIR/gospider -c 40 -t 40 1> /dev/null

    # combine the results and filter out of scope
    cat $TARGETDIR/gospider/* > $TARGETDIR/gospider_raw_out.txt

    # prepare paths list
    grep -e '\[form\]' -e '\[javascript\]' -e '\[linkfinder\]' -e '\[robots\]'  $TARGETDIR/gospider_raw_out.txt | cut -f3 -d ' ' | grep "${SCOPE}" | sort | uniq > $TARGETDIR/gospider/gospider_out.txt
    grep '\[url\]' $TARGETDIR/gospider_raw_out.txt | cut -f5 -d ' ' | grep "${SCOPE}" | sort | uniq >> $TARGETDIR/gospider/gospider_out.txt

    # extract domains
    < $TARGETDIR/gospider/gospider_out.txt unfurl --unique domains | grep "${SCOPE}" | sort | uniq | \
                  $httpxcall >> $TARGETDIR/3-all-subdomain-live-scheme.txt
    echo "[gospider] done."
  fi
}

pagefetcher(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    SCOPE=$1
    echo
    echo "[page-fetch] Fetch page's DOM..."
    < $TARGETDIR/3-all-subdomain-live-scheme.txt page-fetch -o $TARGETDIR/page-fetched --no-third-party --exclude image/ --exclude css/
    grep -horE  "https?[^\"\\'> ]+|www[.][^\"\\'> ]+" $TARGETDIR/page-fetched | grep "${SCOPE}" | sort | uniq | qsreplace -a > $TARGETDIR/page-fetched/pagefetcher_output.txt

    < $TARGETDIR/page-fetched/pagefetcher_output.txt unfurl --unique domains | grep "${SCOPE}" | sort | uniq | \
                  $httpxcall >> $TARGETDIR/3-all-subdomain-live-scheme.txt

    # sort new assets
    sort -u $TARGETDIR/3-all-subdomain-live-scheme.txt -o $TARGETDIR/3-all-subdomain-live-scheme.txt
    echo "[page-fetch] done."
  fi
}

# async ability for execute chromium
screenshots(){
  if [ -s "$TARGETDIR"/3-all-subdomain-live-scheme.txt ]; then
    mkdir "$TARGETDIR"/screenshots
    ./helpers/asyncscreen.sh "$TARGETDIR/3-all-subdomain-live-scheme.txt"
    chown -R $HOMEUSER: $TARGETDIR/screenshots/
    echo "[screenshot] done."
  fi
}

nucleitest(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    echo
    echo "[nuclei] technologies testing..."
    # use -c for maximum templates processed in parallel
    nuclei -silent -l $TARGETDIR/3-all-subdomain-live-scheme.txt -t $HOMEDIR/nuclei-templates/technologies/ -o $TARGETDIR/nuclei/nuclei_output_technology.txt
    echo "[nuclei] CVE testing..."
    nuclei -v -irr -markdown-export $TARGETDIR/nuclei/nucleilog -o $TARGETDIR/nuclei/nuclei_output.txt \
                    -l $TARGETDIR/3-all-subdomain-live-scheme.txt \
                    -t $HOMEDIR/nuclei-templates/vulnerabilities/ \
                    -t $HOMEDIR/nuclei-templates/cves/2014/ \
                    -t $HOMEDIR/nuclei-templates/cves/2015/ \
                    -t $HOMEDIR/nuclei-templates/cves/2016/ \
                    -t $HOMEDIR/nuclei-templates/cves/2017/ \
                    -t $HOMEDIR/nuclei-templates/cves/2018/ \
                    -t $HOMEDIR/nuclei-templates/cves/2019/ \
                    -t $HOMEDIR/nuclei-templates/cves/2020/ \
                    -t $HOMEDIR/nuclei-templates/cves/2021/ \
                    -t $HOMEDIR/nuclei-templates/misconfiguration/ \
                    -t $HOMEDIR/nuclei-templates/network/ \
                    -t $HOMEDIR/nuclei-templates/miscellaneous/ \
                    -exclude $HOMEDIR/nuclei-templates/miscellaneous/old-copyright.yaml \
                    -exclude $HOMEDIR/nuclei-templates/miscellaneous/missing-x-frame-options.yaml \
                    -exclude $HOMEDIR/nuclei-templates/miscellaneous/missing-hsts.yaml \
                    -exclude $HOMEDIR/nuclei-templates/miscellaneous/missing-csp.yaml \
                    -t $HOMEDIR/nuclei-templates/takeovers/ \
                    -t $HOMEDIR/nuclei-templates/default-logins/ \
                    -t $HOMEDIR/nuclei-templates/exposures/ \
                    -t $HOMEDIR/nuclei-templates/exposed-panels/ \
                    -t $HOMEDIR/nuclei-templates/exposures/tokens/generic/credentials-disclosure.yaml \
                    -t $HOMEDIR/nuclei-templates/exposures/tokens/generic/general-tokens.yaml \
                    -t $HOMEDIR/nuclei-templates/fuzzing/
    echo "[nuclei] CVE testing done."

    if [ -s $TARGETDIR/nuclei/nuclei_output.txt ]; then
      cut -f4 -d ' ' $TARGETDIR/nuclei/nuclei_output.txt | unfurl paths | sed 's/^\///;s/\/$//;/^$/d' | sort | uniq > $TARGETDIR/nuclei/nuclei_unfurl_paths.txt
      # filter first and first-second paths from full paths and remove empty lines
      cut -f1 -d '/' $TARGETDIR/nuclei/nuclei_unfurl_paths.txt | sed '/^$/d' | sort | uniq > $TARGETDIR/nuclei/nuclei_paths.txt
      cut -f1-2 -d '/' $TARGETDIR/nuclei/nuclei_unfurl_paths.txt | sed '/^$/d' | sort | uniq >> $TARGETDIR/nuclei/nuclei_paths.txt

      # full paths+queries
      cut -f4 -d ' ' $TARGETDIR/nuclei/nuclei_output.txt | unfurl format '%p%?%q' | sed 's/^\///;s/\/$//;/^$/d' | sort | uniq > $TARGETDIR/nuclei/nuclei_paths_queries.txt
      sort -u $TARGETDIR/nuclei/nuclei_unfurl_paths.txt $TARGETDIR/nuclei/nuclei_paths.txt $TARGETDIR/nuclei/nuclei_paths_queries.txt -o $TARGETDIR/nuclei/nuclei-paths-list.txt
    fi
  fi
}


# prepare custom wordlist for
# ssrf test --mad only mode
# directory bruteforce using --mad and --brute mode only
custompathlist(){
  echo "Prepare custom queryList"
  if [[ -n "$mad" ]]; then
    sort -u $TARGETDIR/wayback/wayback_output.txt $TARGETDIR/gospider/gospider_out.txt $TARGETDIR/page-fetched/pagefetcher_output.txt -o $queryList
    # rm -rf $TARGETDIR/wayback/wayback_output.txt
  else
    sort -u $TARGETDIR/gospider/gospider_out.txt $TARGETDIR/page-fetched/pagefetcher_output.txt -o $queryList
  fi

  if [[ -n "$brute" ]]; then
    echo "Prepare custom customFfufWordList"
    # filter first and first-second paths from full paths remove empty lines
    < $queryList unfurl paths | sed 's/^\///;/^$/d;/web.archive.org/d;/@/d' | cut -f1-2 -d '/' | sort | uniq | sed 's/\/$//' | \
                                                     tee -a $customFfufWordList | cut -f1 -d '/' | sort | uniq >> $customFfufWordList
    sort -u $customFfufWordList -o $customFfufWordList
    chown $HOMEUSER: $customFfufWordList
  fi

  if [[ -n "$fuzz" ]]; then
    chown $HOMEUSER: $queryList
    chown $HOMEUSER: $customSsrfQueryList
    chown $HOMEUSER: $customLfiQueryList
    chown $HOMEUSER: $customSqliQueryList

    # https://github.com/tomnomnom/gf/issues/55
    sudo -u $HOMEUSER helpers/gf-filter.sh ssrf $queryList $customSsrfQueryList &
    pid_01=$!
    sudo -u $HOMEUSER helpers/gf-filter.sh lfi $queryList $customLfiQueryList &
    pid_02=$!
    sudo -u $HOMEUSER helpers/gf-filter.sh sqli $queryList $customSqliQueryList
    wait $pid_01 $pid_02
    echo "Custom queryList done."
  fi
}

# https://rez0.blog/hacking/2019/11/29/rce-via-imagetragick.html
# https://notifybugme.medium.com/finding-ssrf-by-full-automation-7d2680091d68
# https://www.hackerone.com/blog-How-To-Server-Side-Request-Forgery-SSRF
# https://cobalt.io/blog/from-ssrf-to-port-scanner
ssrftest(){
  if [ -s $TARGETDIR/3-all-subdomain-live-scheme.txt ]; then
    echo
    echo "[SSRF-1] Headers..."
    ssrf-headers-tool $TARGETDIR/3-all-subdomain-live-scheme.txt $LISTENSERVER > /dev/null

    echo
    echo "[SSRF-2] Blind probe..."
    # /?url=
    ffuf -c -r -t 250 -u HOST/\?url=https://${LISTENSERVER}/DOMAIN \
        -w $TARGETDIR/3-all-subdomain-live-scheme.txt:HOST \
        -w $TARGETDIR/3-all-subdomain-live-socket.txt:DOMAIN -mode pitchfork -debug-log $TARGETDIR/ffuf_debug.log
    echo "[SSRF-2] Blind probe done."

    if [ -s "$customSsrfQueryList" ]; then
      # similar to paramspider but all wayback without limits
      echo "[SSRF-3] prepare ssrf-list: concat path out from gf ssrf..."
      ITERATOR=0
      while read line; do
        ITERATOR=$((ITERATOR+1))
        # echo "processing $ITERATOR line"
        # echo "[line] $line"
        echo "${line}${LISTENSERVER}" >> $TARGETDIR/ssrf-list.txt
      done < $customSsrfQueryList

      if [ -s $TARGETDIR/ssrf-list.txt ]; then
        echo "[SSRF-3] fuzz gf ssrf endpoints"
        chown $HOMEUSER: $TARGETDIR/ssrf-list.txt
        # simple math to watch progress
        HOSTCOUNT=$(cat $TARGETDIR/3-all-subdomain-live-scheme.txt | wc -l)
        ENDPOINTCOUNT=$(cat $TARGETDIR/ssrf-list.txt | wc -l)
        echo "HOSTCOUNT=$HOSTCOUNT \t ENDPOINTCOUNT=$ENDPOINTCOUNT"
        echo $(($HOSTCOUNT*$ENDPOINTCOUNT))

          ffuf -r -c -t 250 -u HOST/PATH \
              -w $TARGETDIR/3-all-subdomain-live-scheme.txt:HOST \
              -w $TARGETDIR/ssrf-list.txt:PATH > /dev/null
        echo "[SSRF-3] done."
      fi
    fi
  fi
}

# https://www.allysonomalley.com/2021/02/11/burpparamflagger-identifying-possible-ssrf-lfi-insertion-points/
# https://blog.cobalt.io/a-pentesters-guide-to-file-inclusion-8fdfc30275da
lfitest(){
  if [[ -s "$customLfiQueryList" ]]; then
    echo
    echo "[LFI] nuclei testing..."
    nuclei -v -l $customLfiQueryList -o $TARGETDIR/nuclei/lfi_output.txt -t $HOMEDIR/nuclei-templates/vulnerabilities/other/storenth-lfi.yaml
    echo "[LFI] done."
  fi
}
sqlmaptest(){
  if [[ -s "$customSqliQueryList" ]]; then
    # perform the sqlmap
    echo "[sqlmap] SQLi testing..."
    # turn on more tests by swithing: --risk=3 --level=5
    sqlmap -m $customSqliQueryList --batch --random-agent -f --banner --ignore-code=404 --ignore-timeouts  --output-dir=$TARGETDIR/sqlmap/
    echo "[sqlmap] done."
  fi
}

smugglertest(){
  echo "[smuggler.py] Try to find request smuggling vulns..."
  smuggler -u $TARGETDIR/3-all-subdomain-live-scheme.txt

  # check for VULNURABLE keyword
  if [ -s $TARGETDIR/smuggler/output ]; then
    grep 'VULNERABLE' ./smuggler/output > $TARGETDIR/smugglinghosts.txt
    if [ -s $TARGETDIR/smugglinghosts.txt ]; then
      echo "Smuggling vulnerability found under the next hosts:"
      echo
      grep 'VULN' $TARGETDIR/smugglinghosts.txt
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
  if [ -s $TARGETDIR/dnsprobe_ip.txt ]; then
    echo "[masscan] Looking for open ports..."
    # max-rate for accuracy
    # 25/587-smtp, 110/995-pop3, 143/993-imap, 445-smb, 3306-mysql, 3389-rdp, 5432-postgres, 5900/5901-vnc, 27017-mongodb
    # masscan -p0-65535 | -p0-1000,2375,3306,3389,4990,5432,5900,6379,6066,8080,8383,8500,8880,8983,9000,27017 -iL $TARGETDIR/dnsprobe_ip.txt --rate 1000 --open-only -oG $TARGETDIR/masscan_output.gnmap
    masscan -p1-65535 -iL $TARGETDIR/dnsprobe_ip.txt --rate 1000 -oG $TARGETDIR/masscan_output.gnmap
    sleep 1
    sed "${SEDOPTION[@]}" '1d;2d;$d' $TARGETDIR/masscan_output.gnmap # remove 1,2 and last lines from masscan out file
  fi
}

# NSE-approach
# nmap --script "discovery,ftp*,ssh*,http-vuln*,mysql-vuln*,imap-*,pop3-*" -iL $TARGETDIR/nmap_input.txt
nmap_nse(){
  # https://gist.github.com/storenth/b419dc17d2168257b37aa075b7dd3399
  # https://youtu.be/La3iWKRX-tE?t=1200
  # https://medium.com/@noobhax/my-recon-process-dns-enumeration-d0e288f81a8a
  echo "[nmap] scanning..."
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
    # -T4: aggressive time scanning
    # --spoof-mac Cisco: Spoofs the MAC address to match a Cisco product (0=random)
    # -f: used to fragment the packets (i.e. split them into smaller pieces) making it less likely that the packets will be detected by a firewall or IDS.

    # grep smtp /usr/local/Cellar/nmap/7.91/share/nmap/scripts/script.db
    # grep "intrusive" /usr/share/nmap/scripts/script.db
    nmap --spoof-mac 0 -n -sV --version-intensity 9 --script=default,http-headers -sS -Pn -T4 -f -p$PORT -oG $TARGETDIR/nmap/$FILENAME $IP
    echo
    echo
  done < $TARGETDIR/masscan_output.gnmap
}

# directory bruteforce
ffufbrute(){
    echo "Start directory bruteforce using ffuf..."
      mkdir $TARGETDIR/ffuf
      # -c stands for colorized, -s for silent mode
      interlace -tL $TARGETDIR/3-all-subdomain-live-scheme.txt -threads 20 -c "ffuf -c -u _target_/FUZZ -mc all -fc 300,301,302,303,304,400,403,404,406,500,501,502,503 -fs 0 \-w $customFfufWordList -t $dirsearchThreads -p 0.1-2.0 -recursion -recursion-depth 2 -H \"X-Original-URL: /admin\" -H \"User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.192 Safari/537.36\" \-o $TARGETDIR/ffuf/_cleantarget_.html -of html"
      chown -R $HOMEUSER: $TARGETDIR/ffuf
}

recon(){
  enumeratesubdomains $1

  if [[ -n "$mad" && ( -n "$single" || -n "$wildcard" ) ]]; then
    checkwaybackurls $1
  fi

  sortsubdomains $1
  dnsbruteforcing $1
  permutatesubdomains $1

  dnsprobing $1
  checkhttprobe $1 &
  PID_HTTPX=$!
  echo "wait PID_HTTPX=$PID_HTTPX"
  wait $PID_HTTPX

  if [[ -n "$fuzz" || -n "$brute" ]]; then
    gospidertest $1
    pagefetcher $1
    custompathlist $1
  fi

  screenshots $1 &
  PID_SCREEN=$!
  echo "Waiting for screenshots ${PID_SCREEN}"
  wait $PID_SCREEN

  nucleitest $1 &
  PID_NUCLEI=$!
  echo "Waiting for nucleitest ${PID_NUCLEI}..."
  wait $PID_NUCLEI

  if [[ -n "$fuzz" ]]; then
    ssrftest $1
    lfitest $1
    sqlmaptest $1
  fi

  # smugglertest $1 # disabled because still manually work need

  masscantest $1

  if [[ -n "$brute" ]]; then
    ffufbrute $1 # disable/enable yourself (--single preferred) because manually work need on targets without WAF
  fi

  echo "Recon done!"
}

report(){
  echo "Generating HTML-report here..."
  ./helpers/report.sh $1 $TARGETDIR > $TARGETDIR/report.html
  chromium --headless --no-sandbox --print-to-pdf=${TARGETDIR}/report.pdf file://${TARGETDIR}/report.html
  chown $HOMEUSER: $TARGETDIR/report.pdf
  echo "Report done!"
}

main(){
  # VPS used with max wordlist size
  if [[ -n "$vps" ]]; then
    dirsearchWordlist=./wordlist/top10000.txt # used in directory bruteforcing (--brute option)
    dirsearchThreads=10 # to avoid blocking of waf
  else
    dirsearchWordlist=./wordlist/top1000.txt
    dirsearchThreads=20 
  fi
  # collect wildcard and single targets statistic to retest later (optional)
  if [[ -n "$wildcard" ]]; then
    if [ -s $STORAGEDIR/wildcard.txt ]; then
      if ! grep -Fxq $1 $STORAGEDIR/wildcard.txt; then
        echo $1 >> $STORAGEDIR/wildcard.txt
      fi
    fi
  fi

  if [[ -n "$single" ]]; then
    if [ -s $STORAGEDIR/single.txt ]; then
      if ! grep -Fxq $1 $STORAGEDIR/single.txt; then
        echo $1 >> $STORAGEDIR/single.txt
      fi
    fi
  fi

  # parse cidr input to create valid directory
  if [[ -n "$cidr" ]]; then
    CIDRFILEDIR=$(echo $1 | sed "s/\//_/")
    TARGETDIR=$STORAGEDIR/$CIDRFILEDIR/$foldername
    if [ -d "$STORAGEDIR/$CIDRFILEDIR" ]; then
      echo "This is a known target."
    else
      mkdir -p $STORAGEDIR/$CIDRFILEDIR
    fi
  elif [[ -n "$list" ]]; then
    LISTFILEDIR=$(basename $1 | sed 's/[.]txt$//')
    TARGETDIR=$STORAGEDIR/$LISTFILEDIR/$foldername
    if [ -d "$STORAGEDIR/$LISTFILEDIR" ]; then
      echo "This is a known target."
    else
      mkdir -p $STORAGEDIR/$LISTFILEDIR
    fi
  else
    TARGETDIR=$STORAGEDIR/$1/$foldername
    if [ -d "$STORAGEDIR/$1" ]; then
      echo "This is a known target."
    else
      mkdir -p $STORAGEDIR/$1
    fi
  fi
  mkdir -p $TARGETDIR
  [[ -d $TARGETDIR/tmp ]] || mkdir $TARGETDIR/tmp
  echo "target dir created: $TARGETDIR"

  if [[ -n "$fuzz" ]]; then
    # Listen server
    interactsh-client -v &> $TARGETDIR/_listen_server.log &
    SERVER_PID=$!
    sleep 5 # to properly start listen server
    LISTENSERVER=$(tail -n 1 $TARGETDIR/_listen_server.log)
    LISTENSERVER=$(echo $LISTENSERVER | cut -f2 -d ' ')
    echo "Listen server is up $LISTENSERVER with PID=$SERVER_PID"
  fi

  # collect call parameters
  echo "$@" >> $TARGETDIR/_call_params.txt
  echo "$@" >> ./_call.log


  # merges gospider and page-fetch outputs
  queryList=$TARGETDIR/query_list.txt
  touch $queryList

  if [[ -n "$fuzz" || -n "$brute" ]]; then
    mkdir $TARGETDIR/gospider/
    mkdir $TARGETDIR/page-fetched/
    touch $TARGETDIR/gospider/gospider_out.txt
    touch $TARGETDIR/page-fetched/pagefetcher_output.txt
  fi

  # used for fuzz and bruteforce
  if [[ -n "$fuzz" ]]; then
    # to work with gf ssrf output
    customSsrfQueryList=$TARGETDIR/custom_ssrf_list.txt
    touch $customSsrfQueryList
    # to work with gf lfi output
    customLfiQueryList=$TARGETDIR/custom_lfi_list.txt
    touch $customLfiQueryList
    # to work with gf ssrf output
    customSqliQueryList=$TARGETDIR/custom_sqli_list.txt
    touch $customSqliQueryList
  fi

  # ffuf dir uses to store brute output
  if [[ -n "$brute" ]]; then
    customFfufWordList=$TARGETDIR/tmp/custom_ffuf_wordlist.txt
    touch $customFfufWordList
    cp $dirsearchWordlist $customFfufWordList
  fi

  # used to save target specific list for alterations (shuffledns, altdns)
  if [ "$alt" = "1" ]; then
    customSubdomainsWordList=$TARGETDIR/tmp/custom_subdomains_wordlist.txt
    touch $customSubdomainsWordList
    cp $ALTDNSWORDLIST $customSubdomainsWordList
  fi

  # nuclei output
  mkdir $TARGETDIR/nuclei/

  if [ "$mad" = "1" ]; then
    # gau/waybackurls output
    mkdir $TARGETDIR/wayback/
  fi
  # subfinder list of subdomains
  touch $TARGETDIR/subfinder-list.txt 
  # assetfinder list of subdomains
  touch $TARGETDIR/assetfinder-list.txt
  # all assetfinder/subfinder finded domains
  touch $TARGETDIR/enumerated-subdomains.txt
  # gau/waybackurls list of subdomains
  touch $TARGETDIR/wayback-subdomains-list.txt

  # clean up when script receives a signal
  trap clean_up SIGINT

    recon $1
    report $1
}

clean_up() {
  # Perform program interupt housekeeping
  echo
  echo "SIGINT received"
  echo "clean_up..."
  echo "housekeeping rm -rf $TARGETDIR"
  rm -rf $TARGETDIR
  kill_listen_server
  kill_background_pid
  exit 0
}

usage(){
  PROGNAME=$(basename $0)
  echo "Usage: sudo ./lazyrecon.sh <target> [[-b] | [--brute]] [[-m] | [--mad]]"
  echo "Example: sudo $PROGNAME example.com --wildcard"
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
          -s | --single )         single="1"
                                  ;;
          -i | --ip )             ip="1"
                                  ;;
          -f | --fuzz )           fuzz="1"
                                  ;;
          -w | --wildcard )       wildcard="1"
                                  ;;
          -d | --discord )        discord="1"
                                  ;;
          -m | --mad )            mad="1"
                                  ;;
          -l | --list )           list="1"
                                  ;;
          -a | --alt )            alt="1"
                                  ;;
          -c | --cidr )           cidr="1"
                                  ;;
          -b | --brute )          brute="1"
                                  ;;
          -v | --vps )            vps="1"
                                  ;;
          -q | --quiet )          quiet="1"
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

if [ "$quiet" == "" ]; then
  ./helpers/logo.sh
  # env test
  echo "Check HOMEUSER: $HOMEUSER"
  echo "Check HOMEDIR: $HOMEDIR"
  echo "Check STORAGEDIR: $STORAGEDIR"
  echo
  # positional parameters test
  echo "Check params: $*"
  echo "Check # of params: $#"
  echo "Check params \$1: $1"
  echo "Check params \$ip: $ip"
  echo "Check params \$cidr: $cidr"
  echo "Check params \$single: $single"
  echo "Check params \$list: $list"
  echo "Check params \$brute: $brute"
  echo "Check params \$fuzz: $fuzz"
  echo "Check params \$mad: $mad"
  echo "Check params \$brute: $vps"
  echo "Check params \$alt: $alt"
  echo "Check params \$wildcard: $wildcard"
  echo "Check params \$discord: $discord"
  echo
fi


# to avoid cleanup or `sort -u` operation
foldername=recon-$(date +"%y-%m-%d_%H-%M-%S")

# kill listen server
kill_listen_server(){
  if [[ -n "$SERVER_PID" ]]; then
    echo "killing listen server $SERVER_PID..."
    kill -9 $SERVER_PID &> /dev/null || true
  fi
}

# kill background and subshell
# Are you trying to have the parent kill the subprocess, or the subprocess kill the parent?
# At the moment, it's the subprocess that gets the error, and hence runs the error-handler; is it supposed to be killing its parent
kill_background_pid(){
  echo
  echo "killing background jobs by PIDs..."
  echo "subshell before:"
  jobs -l
  jobs -l | awk '{print $2}'| xargs kill -9
  echo

  if [[ -n "$PID_SUBFINDER_FIRST" ]]; then
    echo "kill PID_SUBFINDER_FIRST $PID_SUBFINDER_FIRST"
    kill -- -${PID_SUBFINDER_FIRST} &> /dev/null || true
  fi

  if [[ -n "$PID_ASSETFINDER" ]]; then
    echo "kill PID_ASSETFINDER $PID_ASSETFINDER"
    kill -- -${PID_ASSETFINDER} &> /dev/null || true
  fi

  if [[ -n "$PID_GAU" ]]; then
    echo "kill PID_GAU $PID_GAU"
    kill -- -${PID_GAU} &> /dev/null || true
  fi

  if [[ -n "$PID_WAYBACK" ]]; then
    echo "kill PID_WAYBACK $PID_WAYBACK"
    kill -- -${PID_WAYBACK} &> /dev/null || true
  fi

  if [[ -n "$PID_HTTPX" ]]; then
    echo "kill PID_HTTPX $PID_HTTPX"
    kill -- -${PID_HTTPX} &> /dev/null || true
  fi

  if [[ -n "$PID_SCREEN" ]]; then
    echo "kill PID_SCREEN $PID_SCREEN"
    kill -- -${PID_SCREEN} &> /dev/null || true
  fi

  if [[ -n "$PID_NUCLEI" ]]; then
    echo "kill PID_NUCLEI $PID_NUCLEI"
    kill -- -${PID_NUCLEI} &> /dev/null || true
  fi

  sleep 3
  echo "subshell after:"
  jobs -l
  echo "subshell successfully done."
}

# handle script issues
error_handler(){
  echo
  echo "[ERROR]: LINENO=${LINENO}, SOURCE=$(caller)"
  echo "[ERROR]: $(basename $0): ${FUNCNAME} ${LINENO} ${BASH_LINENO[@]}"
  # stats=$(tail -n 1 _err.log)
  # echo $stats
  if [[ -s ${PWD}/_err.log ]]; then
    < ${PWD}/_err.log
  fi

  kill_listen_server
  kill_background_pid

  if [[ -n "$discord" ]]; then
    ./helpers/discord-hook.sh "[error] line $(caller): ${stats}: "
    if [[ -s ./_err.log ]]; then
      ./helpers/discord-file-hook.sh ./_err.log
    fi
  fi
  exit 1 # exit 1 force kill all subshells because of EXIT signal
}

# handle teardown
error_exit(){
  echo
  echo "[EXIT]: teardown successfully triggered"
  echo "[EXIT]: LINENO=${LINENO}, SOURCE=$(caller)"
  echo "[EXIT]: $(basename $0): ${FUNCNAME} ${LINENO} ${BASH_LINENO[@]}"
  PID_EXIT=$$
  echo "exit PID = $PID_EXIT"
  echo "jobs:"
  jobs -l
  jobs -l | awk '{print $2}' | xargs kill -9 &>/dev/null || true
  kill -- -${PID_EXIT} &>/dev/null || true
  rm -rf $TARGETDIR/tmp
  find . -type f -empty -delete
  echo "[EXIT] done."
}

trap error_handler ERR
trap error_exit EXIT

# invoke
main "$@"

echo "check for background and subshell"
jobs -l

if [[ -n "$discord" ]]; then
  ./helpers/discord-hook.sh "[info] $1 done"
    if [[ -s $TARGETDIR/report.pdf ]]; then
      # check then file more then maximum of 8MB to pass the discord
      if (($(ls -l $TARGETDIR/report.pdf | awk '{print $5}') > 8000000)); then
            split -b 8m $TARGETDIR/report.pdf $TARGETDIR/tmp/_report_
            for file in $TARGETDIR/tmp/_report_*; do
                ./helpers/discord-file-hook.sh "$file"
            done
      else 
          ./helpers/discord-file-hook.sh $TARGETDIR/report.pdf
      fi
    fi
fi
kill_listen_server

exit 0
