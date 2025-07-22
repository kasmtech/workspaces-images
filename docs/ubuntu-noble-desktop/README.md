# About This Image

This Image contains a browser-accessible Ubuntu Noble Desktop with various productivity and development apps installed.

![Screenshot][Image_Screenshot]

[Image_Screenshot]: https://5856039.fs1.hubspotusercontent-na1.net/hubfs/5856039/dockerhub/image-screenshots/ubuntu_jammy_desktop.png "Image Screenshot"

This image contains the Signal app pre-installed. Signal enforces strict security rules that block network access if it detects SSL inspection (MitM). To ensure Signal functions correctly when **WebFilter** is enabled, you must add these domains to the **SSL Bypass Domains** list in your **WebFilter configuration**:  (Notice the preceding dot (.) that ensures all subdomains are also bypassed)
```
.signal.org
.signal.art
.signal.tube
.signal.group
.signal.link
.signal.me
```
