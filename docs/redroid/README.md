# About This Image

This Image contains a browser-accessible version of [Redroid](https://github.com/remote-android/redroid-doc).

![Screenshot][Image_Screenshot]

[Image_Screenshot]: https://f.hubspotusercontent30.net/hubfs/5856039/dockerhub/image-screenshots/redroid.png "Image Screenshot"
## Important !!

This image requires host level kernel modules to be installed and loaded.
See [Redroid Docs](https://github.com/remote-android/redroid-doc?tab=readme-ov-file#getting-started) for more details


# Environment Variables

* `REDROID_GPU_GUEST_MODE` - Used to instruct redroid to utilize GPU rendering. Options are `auto`, `guest`, and `host`
* `REDROID_FPS` - Set the maximum FPS for redroid and scrcpy
* `REDROID_WIDTH` - Set the desired width of the redroid device
* `REDROID_HEIGHT` - Set the desired height of the redroid device
* `REDROID_DPI` - Set the desired DPI of the redroid device
* `REDROID_SHOW_CONSOLE` - Display the scrcpy console after launching the redroid device.
* `REDROID_DISABLE_AUTOSTART` - If set to "1", the container will not automatically pull and start the redroid container and scrcpy.
* `REDROID_DISABLE_HOST_CHECKS` - If set to "1", the container will not check for the presence of required host level kernel modules.
