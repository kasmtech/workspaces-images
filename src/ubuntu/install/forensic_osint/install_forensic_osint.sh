#!/bin/bash
set -ex

# Install the Forensic OSINT extension
cat >/etc/opt/chrome/policies/managed/forensic_osint.json <<EOL
{
    "ExtensionSettings": {
        "*": {
        },
        "jojaomahhndmeienhjihojidkddkahcn": {
            "installation_mode": "force_installed",
            "update_url": "https://clients2.google.com/service/update2/crx",
            "toolbar_pin" : "force_pinned"
        }
    }
}
EOL
