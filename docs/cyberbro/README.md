# About This Image

This Image contains a browser-accessible version of [Cyberbro](https://github.com/stanfrbd/cyberbro).

![Screenshot][Image_Screenshot]

[Image_Screenshot]: https://github.com/user-attachments/assets/f6ffb648-e161-4c59-9359-51183b0b0ca0 "Image Screenshot"

# Environment Variables

## Firefox Configuration

* `APP_ARGS` - Additional arguments to pass to firefox when launched (e.g `--no-sandbox`).

## Cyberbro Configuration

Here is a list of all available environment variables that can be used with examples:

```bash
PROXY_URL=http://127.0.0.1:9000
VIRUSTOTAL=api_key_here
ABUSEIPDB=api_key_here
IPINFO=api_key_here
GOOGLE_SAFE_BROWSING=api_key_here
MDE_TENANT_ID=api_key_here
MDE_CLIENT_ID=api_key_here
MDE_CLIENT_SECRET=api_key_here
SHODAN=api_key_here
OPENCTI_API_KEY=api_key_here
OPENCTI_URL=https://demo.opencti.io
API_PREFIX=my_api
GUI_ENABLED_ENGINES=reverse_dns,rdap,hudsonrock,mde,shodan,opencti,virustotal
CONFIG_PAGE_ENABLED=true
```

You can pass these environment variables to your Cyberbro Workspace with **Docker Run Config Override (JSON)** in your Workspace settings.


> Note: if you set `GUI_ENABLED_ENGINES` to `""` then all engines will be enabled in the GUI. \
> By default, all **free engines** will be enabled in the GUI.

Refer to [Cyberbro Wiki](https://github.com/stanfrbd/cyberbro/wiki) for more information.