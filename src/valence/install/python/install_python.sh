#!/usr/bin/env bash
set -ex

# Default Python version if not specified
PYTHON_VERSION=${PYTHON_VERSION:-3.9.13}

# Install dependencies
apt-get update
apt-get install -y --no-install-recommends \
    wget \
    build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev

# Download and install Python
wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
tar xzf Python-${PYTHON_VERSION}.tgz
cd Python-${PYTHON_VERSION}
./configure --enable-optimizations
make -j $(nproc)
make altinstall

# Create symbolic links
ln -sf /usr/local/bin/python${PYTHON_VERSION%.*} /usr/local/bin/python3
ln -sf /usr/local/bin/python${PYTHON_VERSION%.*} /usr/local/bin/python
ln -sf /usr/local/bin/pip${PYTHON_VERSION%.*} /usr/local/bin/pip3
ln -sf /usr/local/bin/pip${PYTHON_VERSION%.*} /usr/local/bin/pip

# Verify installation
python --version
pip --version

# Cleanup
cd ..
rm -rf Python-${PYTHON_VERSION} Python-${PYTHON_VERSION}.tgz
if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get clean
    rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*
fi

# Set permissions
chown -R 1000:0 /usr/local/lib/python*