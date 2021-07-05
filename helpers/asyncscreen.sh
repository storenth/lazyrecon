#!/bin/bash
# kill used as workaround:
# https://bugs.chromium.org/p/chromium/issues/detail?id=1097565&can=2&q=component%3AInternals%3EHeadless

# threads
THREADS=8
# to handle background PID of screenshot
declare -a PID_CHROMIUM

if [ -s "${1}" ]; then
  ITERATOR=0

  while read line; do
    echo
    echo "[screenshot] new target..."
    echo $line
    DIRNAMEPATH=$(dirname "${1}")
      # check if target is IP address
      ISIP=$(echo "$line" | grep -oE "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])")
      if [[ -n "$ISIP" ]]; then
        SCOPE=$(echo "$line" | grep -oiahE "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])([:][[:digit:]]{2,4})?" | sed "s/:/_/;s/[.]/_/g")
      else
        SCOPE=$(echo "$line" | grep -oiahE "(([[:alpha:][:digit:]-]+\.)+)?[[:alpha:][:digit:]-]+\.[[:alpha:]]{2,5}([:][[:digit:]]{2,4})?" | sed "s/:/_/;s/[.]/_/g")
      fi

      /usr/local/bin/chromium --headless --no-sandbox --disable-setuid-sandbox --user-data-dir="/tmp" --disable-web-security \
                              --disable-extensions --ignore-urlfetcher-cert-requests --ignore-certificate-errors --ignore-ssl-errors --disable-dev-shm-usage \
                              --window-size=1280,720 --screenshot="${DIRNAMEPATH}/screenshots/${SCOPE}.png" $line &

        PID_CHROMIUM[$ITERATOR]=$!
        echo "PID_CHROMIUM=${PID_CHROMIUM[@]}"
        ITERATOR=$((ITERATOR+1))

        if [ $((ITERATOR % THREADS)) -eq 0 ]; then
          sleep 10
            for PID_TMP in "${!PID_CHROMIUM[@]}"; do
                echo "#PID_CHROMIUM=${#PID_CHROMIUM[@]}"
                echo "killing ${PID_CHROMIUM[$PID_TMP]}"
                kill -9 "${PID_CHROMIUM[$PID_TMP]}" || true
                unset PID_CHROMIUM[$PID_TMP]
            done
        fi

  done < "${1}"

  # remaining targets
  echo
  echo "[screenshot] remaining targets: ${#PID_CHROMIUM[@]}"
  sleep 10
  for PID_TMP in "${!PID_CHROMIUM[@]}"; do
      echo "killing ${PID_CHROMIUM[$PID_TMP]}"
      kill -9 "${PID_CHROMIUM[$PID_TMP]}" || true
      unset PID_CHROMIUM[$PID_TMP]
  done

  echo "[screenshot][debug] jobs -l:"
  jobs -l
  jobs -l | awk '{print $2}' | xargs kill -9 &>/dev/null || true
else
  echo "No such file ${1}"
  exit 1
fi
