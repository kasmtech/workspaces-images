# About This Image

This Image contains a browser-accessible version of [TRAE IDE CN](https://www.trae.cn).

# Feature Improvements

- Default setting `enable_ime` to enable local input method

# How to Use

- Start Container

    ```bash
    docker run -dit --name trae \
        --user root \
        -e KASM_USER=admin \
        -e VNC_PW=Password123 \
        -e TRAE_WORKDIR=/trae \
        -v ./trae:/trae \
        --shm-size 1g \
        -p 36901:6901 \
        kasmweb/trae-cn:2.3.27641
    ```

- Use Compose

    ```yaml
    version: '3.8'
    services:
      trae:
        image: kasmweb/trae-cn:2.3.27641
        container_name: trae
        user: root
        environment:
          - KASM_USER=admin
          - VNC_PW=Password123
          - TRAE_WORKDIR=/trae
        volumes:
          - ./trae:/trae
        shm_size: 1g
        ports:
          - "36901:6901"
        restart: unless-stopped
    ```

In the configuration:

1. `KASM_USER` and `VNC_PW` are the username and password for browser access
2. `TRAE_WORKDIR` is the working directory for TRAE, which needs to match the mounted volume path. After TRAE starts, it will automatically open the `$TRAE_WORKDIR/workspace` directory, and save configurations and extensions to the `$TRAE_WORKDIR` directory
