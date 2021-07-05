#!/bin/bash -x

# tested on DigitalOcean Ubuntu droplet

# github-search Bug-Bounty-Toolz dependencies
apt install -y python3-pip
# masscan massdns chromium-latest-linux dependencies
apt install -y make gcc unzip

# chromium dependencies
# https://github.com/puppeteer/puppeteer/blob/main/docs/troubleshooting.md
apt-get install ca-certificates fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 lsb-release wget xdg-utils
