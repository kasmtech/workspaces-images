#!/usr/bin/env bash
set -ex
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
GOVER='1.19.2'
# Remove any previous Go installation (if it exists), then extract the new archive into /usr/local
wget -q https://go.dev/dl/go${GOVER}.linux-${ARCH}.tar.gz -O golang.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf golang.tar.gz

# add /usr/local/go/bin to the PATH environment variable
export PATH=$PATH:/usr/local/go/bin
echo "PATH=\$PATH:/usr/local/go/bin" | tee -i /etc/bash.bashrc

# config go mod mirror site
go env -w GO111MODULE=on
#go env -w GOPROXY=https://goproxy.cn,direct  # for china user only

# install go tools
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/josharian/impl@latest
#go get -u github.com/cweill/gotests/...

# clear up
go clean --modcache
rm -rf golang.tar.gz