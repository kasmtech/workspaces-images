#!/usr/bin/env bash
### every exit != 0 fails the script
set -ex

# Add this user pref so the tabs dont crash regularly
cp /usr/lib/firefox/browser/defaults/profile/user.js /usr/lib/firefox/browser/defaults/profile/user.js.bak
echo "user_pref(\"browser.startup.firstrunSkipsHomepage\", false);" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"browser.shell.skipDefaultBrowserCheckOnFirstRun\", true);" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"startup.homepage_welcome_url\", \"about:blank\");" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"datareporting.policy.firstRunURL\", \"\");" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"startup.homepage_welcome_url.additional\", \"\");" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"browser.shell.checkDefaultBrowser\", false);" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"app.update.auto\", false);" >> /usr/lib/firefox/browser/defaults/profile/user.js
echo "user_pref(\"app.update.enabled\", false);" >> /usr/lib/firefox/browser/defaults/profile/user.js