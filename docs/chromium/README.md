# About This Image

This Image contains a browser-accessible version of [Chromium](https://www.chromium.org/Home).

![Screenshot][Image_Screenshot]

[Image_Screenshot]: https://f.hubspotusercontent30.net/hubfs/5856039/dockerhub/image-screenshots/chromium.png "Image Screenshot"

# Environment Variables

* `LAUNCH_URL` - The default URL the browser launches to when created.
* `APP_ARGS` - Additional arguments to pass to the browser when launched.
* `KASM_RESTRICTED_FILE_CHOOSER` - Confine "File Upload" and "File Save"
  dialogs to ~/Desktop. On by default.
