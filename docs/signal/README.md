# About This Image

This Image contains a browser-accessible version of [Signal](https://signal.org/).

![Screenshot][Image_Screenshot]

[Image_Screenshot]: https://f.hubspotusercontent30.net/hubfs/5856039/dockerhub/image-screenshots/signal.png "Image Screenshot"

This image contains the Signal app pre-installed. Signal enforces strict security rules that block network access if it detects SSL inspection (MitM). To ensure Signal functions correctly when **WebFilter** is enabled, you must add these domains to the **SSL Bypass Domains** list in your **WebFilter configuration**:  (Notice the preceding dot (.) that ensures all subdomains are also bypassed)
```
.signal.org
.signal.art
.signal.tube
.signal.group
.signal.link
.signal.me
```

# Environment Variables

* `APP_ARGS` - Additional arguments to pass to the application when launched.
