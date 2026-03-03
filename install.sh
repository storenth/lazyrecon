#!/bin/bash -x

# Script works in current directory

# https://golang.org/doc/install#install
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$HOME/go/bin:$HOMEDIR/go/bin

MACOS=
if [[ "$OSTYPE" == "darwin"* ]]; then
  MACOS="1"
fi

# sqlmap and linkfinder needs change python to python3
# mac m1 issue
# if ! /usr/bin/env python -h; then
#     sudo ln -s /usr/local/bin/python3 /usr/bin/python
# fi

# CI/CD dependencies
third_party_go_dependencies(){
    # Third-party tools
        go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
        go install github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest
        go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

        go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
        go install github.com/blechschmidt/massdns@latest
        # jq is required for report formatting
        if ! type jq; then
            if [[ -n "$MACOS" ]]; then
                brew install jq
            else
                sudo apt-get install -y jq
            fi
        fi
        nuclei -ut -ud "$HOMEDIR/nuclei-templates"
}


notification(){
    echo
    echo "Dependencies installed in $PWD"
}

main() {
    # Entry point
    third_party_go_dependencies

    notification
}

main
exit 0
