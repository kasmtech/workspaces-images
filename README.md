![Logo][logo]
# Workspaces Images
This repository contains several example of desktop and application Workspaces images.
Administrators may leverage these images directly or use them as a starting point for their own custom images.
Each of these images is based off one of the [**Workspaces Core Images**](https://github.com/kasmtech/workspaces-core-images?utm_campaign=Github&utm_source=github) which contain the necessary wiring to work within the Kasm Workspaces platform.


For more information about building custom images please review the  [**How To Guide**](https://docs.kasm.com/docs/latest/how-to/workspaces-sessions/container-workspace/customization/building-images?utm_campaign=Github&utm_source=github)

The Kasm team publishes applications and desktop images for use inside the platform. More information, including source can be found in the [**Default Images List**](https://docs.kasm.com/docs/latest/how-to/workspaces-sessions/container-workspace/custom-images?utm_campaign=Github&utm_source=github)


# Manual Deployment

To build the provided images:

    sudo docker build -t kasmweb/firefox:dev -f dockerfile-kasm-firefox .


While these image are primarily built to run inside the Workspaces platform, they can also be executed manually.  Please note that certain functionality, such as audio, uploads, downloads, and microphone pass-through are only available within the Kasm platform.

```
sudo docker run --rm  -it --shm-size=512m -p 6901:6901 -e VNC_PW=password kasmweb/firefox:dev
```

The container is now accessible via a browser : `https://<IP>:6901`

 - **User** : `kasm_user`
 - **Password**: `password`


# About Workspaces
Kasm Workspaces is a docker container streaming platform that enables you to deliver browser-based access to desktops, applications, and web services. Kasm uses a modern DevOps approach for programmatic delivery of services via Containerized Desktop Infrastructure (CDI) technology to create on-demand, disposable, docker containers that are accessible via web browser. The rendering of the graphical-based containers is powered by the open-source project   [**KasmVNC**](https://github.com/kasmtech/KasmVNC?utm_campaign=Github&utm_source=github)

![Screenshot][Kasm_Workflow]

Kasm Workspaces was developed to meet the most demanding secure collaboration requirements that is highly scalable, customizable, and easy to maintain.  Most importantly, Kasm provides a solution, rather than a service, so it is infinitely customizable to your unique requirements and includes a developer API so that it can be integrated with, rather than replace, your existing applications and workflows. Kasm can be deployed in the cloud (Public or Private), on-premise (Including Air-Gapped Networks), or in a hybrid configuration.

# Live Demo
A self-guided on-demand demo is available at [**kasm.com**](https://app.kasm.com/#/cast/kasmos)

# Building Images

Build scripts for creating workspace images locally are in `scripts/` and require
[`yq`](https://github.com/mikefarah/yq) v4.53.3 (downloaded and sha256-verified automatically on first run; cached at `~/.cache/kasm/yq/`).

All commands must be run from the repository root.

## List available images

```
./scripts/build-image.sh --list-images
```

## Build an image

To build an image directly (tagged `local_build` by default):

```
./scripts/build-image.sh --build kasmweb/ubuntu-jammy-desktop
```

To inspect the `docker build` command before running it:

```
./scripts/build-image.sh --list-image-build-command kasmweb/ubuntu-jammy-desktop
```

To list build commands for all images:

```
./scripts/build-image.sh --list-images-build-commands
```

Override the image tag with `-t`:

```
./scripts/build-image.sh --build kasmweb/ubuntu-jammy-desktop -t my-tag
```


[logo]: https://5856039.fs1.hubspotusercontent-na1.net/hubfs/5856039/Kasm_Workspaces_Logo.png "Kasm Logo"
[Kasm_Workflow]: https://5856039.fs1.hubspotusercontent-na1.net/hubfs/5856039/dockerhub/launching_ubuntu_jammy.gif "Kasm Workflow"

# Reporting Issues

To report any issues for this repository, please use our central issue tracker: **[Kasm Workspaces Issue Tracker](https://github.com/kasmtech/workspaces-issues/issues)**
