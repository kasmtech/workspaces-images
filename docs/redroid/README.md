# About This Image

This experimental image contains a browser-accessible version of [Redroid](https://github.com/remote-android/redroid-doc).
redroid (Remote-Android) is a multi-arch, GPU enabled, Android in Cloud solution.

The image utilizes Docker in Docker (DinD) to automate launching Redroid and [scrcpy docs](https://github.com/Genymobile/scrcpy).

![Screenshot][Image_Screenshot]

[Image_Screenshot]: https://f.hubspotusercontent30.net/hubfs/5856039/dockerhub/image-screenshots/redroid.png "Image Screenshot"
## Host Dependencies

This image requires the "binder_linux" host level kernel modules installed and enabled. 

Below is an example for installing binder_linux on Ubuntu 22.04 LTS host
```
sudo apt install linux-modules-extra-`uname -r`
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
```
See [Redroid Docs](https://github.com/remote-android/redroid-doc?tab=readme-ov-file#getting-started) for more details.


## Container Permissions

Using this container requires the `--privileged` flag to power both the Docker in Docker processes and the permissions
needed by the redroid containers

```
sudo docker run --rm -it --privileged --shm-size=512m -p 6901:6901 -e VNC_PW=password kasmweb/redroid:develop
```

## Example for installing binder_linux on Ubuntu 22.04 LTS host
```
sudo apt install linux-modules-extra-`uname -r`
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
```

The left ALT key is mapped as the hotkey for scrcpy

- Alt+R - rotate the android device
- Alt+F - fullscreen the android device
- Alt+Up/Alt+Down - Increase the volume of the device

See [scrcpy docs](https://github.com/Genymobile/scrcpy) for more details.



# Environment Variables

* `REDROID_GPU_GUEST_MODE` - Used to instruct redroid to utilize GPU rendering. Options are `auto`, `guest`, and `host`
* `REDROID_FPS` - Set the maximum FPS for redroid and scrcpy.
* `REDROID_WIDTH` - Set the desired width of the redroid device.
* `REDROID_HEIGHT` - Set the desired height of the redroid device.
* `REDROID_DPI` - Set the desired DPI of the redroid device.
* `REDROID_SHOW_CONSOLE` - Display the scrcpy console after launching the redroid device.
* `REDROID_DISABLE_AUTOSTART` - If set to "1", the container will not automatically pull and start the redroid container and scrcpy.
* `REDROID_DISABLE_HOST_CHECKS` - If set to "1", the container will not check for the presence of required host level kernel modules.
* `ANDROID_VERSION` - The version of android (redroid) image to automatically load. Options are `14.0.0`, `13.0.0` (Default), `12.0.0`, `11.0.0`, `10.0.0`, `9.0.0`, `8.1.0`.
