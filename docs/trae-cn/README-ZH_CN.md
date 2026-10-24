# About This Image

This Image contains a browser-accessible version of [TRAE IDE CN](https://www.trae.cn).

这个镜像在Kasm镜像基础上安装了 TRAE IDE CN 的 .deb(x64) 版本。

# 功能改进

- 默认设置 `enable_ime`，开启本地输入法

# How to Use

- 启动容器

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

- 使用compose

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

在配置中：

1. `KASM_USER` 和 `VNC_PW` 是浏览器访问的用户名和密码
2. `TRAE_WORKDIR` 是TRAE的工作目录，需要与挂载卷的路径一致，TRAE启动后会默认打开`$TRAE_WORKDIR/workspace`目录，同时保存配置和扩展到`$TRAE_WORKDIR`目录下
