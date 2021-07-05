# Installing
Tested on `MacOS` and `Linux`

## Prerequirements
```bash
python >= 3.7
pip3 >= 19.0
go >= 1.14
```

## Dependencies
- To start using lazyrecon script, please clone and setup the dependencies bellow
- Make sure environment variables are filled in `./lazyconfig`
- Update your local `~/.gf` with `./gfpatterns/*`
- Use option `nuclei -update-templates` to use it properly under `$HOMEDIR`, but for LFI update templates with [storenth-lfi](https://github.com/storenth/nuclei-templates/blob/master/vulnerabilities/other/storenth-lfi.yaml) till the time [projectdiscovery](https://github.com/projectdiscovery) introduce feature for dynamic replacement of parameters.
- Make sure all tools correctly installed and enabled with execute permissions: `chmod +x`
- Check for your router configuration to handle incoming TCP connection on the port you specify
- Take care about appropriate tokens and API keys
- Don't forget that the script act as a root user
1. [subfinder](https://github.com/projectdiscovery/subfinder)
2. [interactsh](https://github.com/projectdiscovery/interactsh)
3. [assetfinder](https://github.com/tomnomnom/assetfinder)
4. [github-subdomains](https://github.com/storenth/github-search/blob/master/github-subdomains.py)
5. [github-endpoints](https://github.com/storenth/github-search/blob/master/github-endpoints.py)
6. [waybackurls](https://github.com/tomnomnom/waybackurls)
7. [gau](https://github.com/lc/gau)
8. [altdns](https://github.com/infosec-au/altdns)
9. [dnsgen](https://github.com/ProjectAnte/dnsgen/)
10. [shuffledns](https://github.com/projectdiscovery/shuffledns)
11. [masscan](https://github.com/robertdavidgraham/masscan)
12. [dnsx](https://github.com/projectdiscovery/dnsx)
13. [httpx](https://github.com/projectdiscovery/httpx)
14. [nuclei](https://github.com/projectdiscovery/nuclei)
15. [nuclei-templates](https://github.com/storenth/nuclei-templates)
16. [smuggler](https://github.com/storenth/requestsmuggler)
17. [ffuf](https://github.com/ffuf/ffuf)
18. [hydra](https://github.com/vanhauser-thc/thc-hydra)
19. [gf](https://github.com/tomnomnom/gf)
20. [qsreplace](https://github.com/tomnomnom/qsreplace)
21. [unfurl](https://github.com/tomnomnom/unfurl)
22. [sqlmap](https://github.com/sqlmapproject/sqlmap)
23. [gospider](https://github.com/jaeles-project/gospider)
24. [hakrawler](https://github.com/hakluke/hakrawler)
25. [ssrf-headers-tool](https://github.com/storenth/Bug-Bounty-Toolz/blob/master/ssrf.py)
26. [storenth-lfi](https://github.com/storenth/nuclei-templates/blob/master/vulnerabilities/other/storenth-lfi.yaml)
27. [nmap](https://nmap.org/download.html)
28. [chromium](https://github.com/storenth/chromium-latest-linux.git)
29. [interlace](https://github.com/codingo/Interlace.git)
30. [page-fetch](https://github.com/detectify/page-fetch)

> (You may copy each executable dependency to `/usr/local/bin/`, create symlinc like: `ln -s $HOME/github-subdomains.py /usr/local/bin/github-subdomains`, or just export it to the PATH `export PATH=~/masscan/bin/masscan:$PATH`)
