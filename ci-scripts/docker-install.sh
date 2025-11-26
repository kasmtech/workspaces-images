#!/bin/bash

function install_centos (){
    echo "CentOS 7.x/8.x/9.x Install"
    echo "Installing Base CentOS Packages"

    NO_BEST=""
    if [ "${1}" == '"8"' ] || [ "${1}" == '"9"' ]; then
        NO_BEST="--nobest"
    fi

    yum install -y yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        lsof \
        nc

    yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo

    echo "Installing Docker-CE"
    yum install -y docker-ce docker-compose-plugin $NO_BEST
    systemctl start docker
}


function install_ubuntu (){
    echo "Ubuntu 18.04/20.04/22.04/24.04 Install"
    echo "Installing Base Ubuntu Packages"
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        netcat-openbsd \
        software-properties-common

    if dpkg -s docker-ce | grep Status: | grep installed ; then
      echo "Docker Installed"
    else
      echo "Installing Docker-CE"

      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
      add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      apt-get update
      apt-get -y install docker-ce docker-compose-plugin
    fi
}

function install_debian (){
    echo "Debian 10.x/11.x/12.x Install"
    echo "Installing Base Debian Packages"
    apt-get update
    apt-get install -y \
         apt-transport-https \
         ca-certificates \
         curl \
         gnupg2 \
          netcat-openbsd \
         software-properties-common

    if dpkg -s docker-ce | grep Status: | grep installed ; then
      echo "Docker Installed"
    else
      echo "Installing Docker-CE"

      curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
      mkdir -p /etc/apt/sources.list.d
      echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get -y install docker-ce docker-compose-plugin
    fi
}

function install_oracle (){
    echo "RHEL Linux 7.x/8.x/9.x Install"
    echo "Installing Base Packages"

    NO_BEST=""
    if [[ "${1}" == '"8.'* ]] || [[ "${1}" == '"9.'* ]]; then
        NO_BEST="--nobest"
    else
        yum-config-manager --enable ol7_developer
    fi

    yum install -y yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        lsof \
        nc

    yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo

    echo "Installing Docker-CE"
    yum install -y docker-ce docker-compose-plugin $NO_BEST
    systemctl start docker
}

if [ -f /etc/os-release ] ; then
    OS_ID="$(awk -F= '/^ID=/{print $2}' /etc/os-release)"
    OS_VERSION_ID="$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release)"
fi

case $OS_ID in
    "ubuntu")
        install_ubuntu
    ;;
    "debian")
        install_debian
    ;;
    "centos")
        install_centos ${OS_VERSION_ID}
    ;;
    "ol")
        install_oracle ${OS_VERSION_ID}
    ;;
    "rocky")
        install_oracle ${OS_VERSION_ID}
    ;;
    "almalinux")
        install_oracle ${OS_VERSION_ID}
    ;;
    "rhel")
        install_oracle ${OS_VERSION_ID}
    ;;
    *)
        echo "OS not supported"
        exit 1
    ;;
esac