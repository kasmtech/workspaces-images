#!/usr/bin/env bash
set -xe

apt-get update
apt-get install -y unzip
# In new firefox you can taylor the way the toolbars look via this stylesheet
#   Here we:
#   Remove the tabs toolbar
#   Remove the  scrollbar
#   Remove the Main Menu
#   Remove teh Forward Bar
#   Remove the Page actions from the url bar
#   Remove cursor
mkdir -p $HOME/.mozilla/firefox/kasm/chrome
cat >$HOME/.mozilla/firefox/kasm/chrome/userChrome.css <<EOL
#content browser, .browserStack>browser {
	margin-right:-17px!important;
	margin-bottom:-17px!important;
	overflow-y:scroll;
	overflow-x:hidden;
}

#TabsToolbar { visibility: collapse !important; }
#PanelUI-menu-button {display: none;}
#forward-button{
    display:none !important;
}
#pageActionButton { display: none !important; }
* { cursor: none !important }
EOL

cat >$HOME/.mozilla/firefox/kasm/chrome/userContent.css <<EOL
* { cursor: none !important }
EOL
chown -R 1000:1000 $HOME/.mozilla/firefox/kasm/chrome

# --- Set up global preferences for a better look and feel on mobile devices ---


# Set the user agent to a mobile variant. This is helpful since many sophisticated sites will send a mobile tailored
#   site instead of desktop variant
echo "pref(\"general.useragent.override\", \"Mozilla/5.0 (iPhone; CPU iPhone OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/10.4b8288 Mobile/15E302 Safari/605.1.15\");" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js

# Light theme
echo "pref(\"lightweightThemes.selectedThemeID\", \"firefox-compact-light@mozilla.org\");" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js

# No Title bar
echo "pref(\"browser.tabs.drawInTitlebar\", true);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js

# When typing in the urlbar FF displays a massive dropdown that consumes the whole screen on mobile with search
#   suggestions etc. We remove all that so when the user starts typing the dropdown doesnt go over the keyboard
#   thus preventing them from typing
echo "pref(\"browser.urlbar.suggest.bookmark\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.urlbar.suggest.history\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.urlbar.suggest.openpage\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.search.suggest.enabled\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.search.suggest.searches\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.urlbar.autoFill\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.urlbar.autocomplete.enabled\", false);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.search.hiddenOneOffs\", \"Google,Bing,Amazon.com,DuckDuckGo,eBay,Twitter,Wikipedia (en)\");" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js

# These preferences are aimed at minimizing interferences from popups. After these configs.
# After these configs any links should be opened in the current and only tab.
# Before it was easy to get into a state where a page forces open a new window or tab and the user cant get back to
# where they were:

echo "pref(\"browser.link.open_newwindow\", 1);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"browser.tabs.maxOpenBeforeWarn\", 1);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"dom.popup_allowed_events\", \" \");" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js
echo "pref(\"dom.popup_maximum\", 0);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js


# Remove the addon from the menu and into another section. This may not be future proof
echo "user_pref(\"browser.uiCustomization.state\", \"{\\\"placements\\\":{\\\"widget-overflow-fixed-list\\\":[],\\\"PersonalToolbar\\\":[\\\"personal-bookmarks\\\"],\\\"nav-bar\\\":[\\\"back-button\\\",\\\"urlbar-container\\\",\\\"forward-button\\\"],\\\"TabsToolbar\\\":[\\\"tabbrowser-tabs\\\",\\\"new-tab-button\\\",\\\"alltabs-button\\\"],\\\"toolbar-menubar\\\":[\\\"menubar-items\\\"]},\\\"seen\\\":[\\\"dragtoscroll_deag1bcc-abec-daec-cdae-aeadedcabebacdad-browser-action\\\",\\\"developer-button\\\"],\\\"dirtyAreaCache\\\":[\\\"PersonalToolbar\\\",\\\"nav-bar\\\",\\\"TabsToolbar\\\",\\\"toolbar-menubar\\\"],\\\"currentVersion\\\":14,\\\"newElementCount\\\":0}\");" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js


# Change the UI density to be a bit more mobile friendly.
echo "pref(\"browser.uidensity\", 2);" >> /usr/lib/firefox/browser/defaults/preferences/firefox.js

# Remove the bookmark icons from the urlbar to get back a few more pixels
echo "pref(\"browser.pageActions.persistedActions\", \"{\\\"version\\\":1,\\\"ids\\\":[\\\"bookmark\\\",\\\"bookmarkSeparator\\\",\\\"copyURL\\\",\\\"emailLink\\\",\\\"sendToDevice\\\",\\\"pocket\\\",\\\"screenshots\\\"],\\\"idsInUrlbar\\\":[]}\");"  >> /usr/lib/firefox/browser/defaults/preferences/firefox.js

# The xulstore.json is yet another place to define the layout of certain components. Here we set up the window
#   to remove some of the excess buttons from the toolbar that you cant do elsewhere like Forward
cat >$HOME/.mozilla/firefox/kasm/xulstore.json <<EOL
{"chrome://browser/content/browser.xul":{"toolbar-menubar":{"autohide":"true","currentset":"menubar-items"},"TabsToolbar":{"currentset":"tabbrowser-tabs,new-tab-button,alltabs-button"},"nav-bar":{"currentset":"back-button,urlbar-container"},"sidebar-box":{"sidebarcommand":"","width":""},"sidebar-title":{"value":""}}}
EOL


# Install the Drag to Scroll extension
#   This extension gives a more natural "mobile scroll" behavior that you get on native mobile devices
#   without this the user would have to clock and drag the mini scroll bar.
#   There are a few of ways to install addons, however the method below does not require user intervention when
#   starting FF for the first time. Its installed for all users.

EXTENSIONS_SYSTEM='/usr/lib/firefox-addons/distribution/extensions/'
EXTENSION_URL='https://s3.amazonaws.com/kasm-static-content/dragtoscroll.xpi'
rm -rf ~/extension
rm -rf $EXTENSIONS_SYSTEM
mkdir -p $EXTENSIONS_SYSTEM
mkdir -p ~/extension
cd ~/extension
wget -q $EXTENSION_URL -O addon.xpi
unzip addon.xpi
ADDON_NAME=`cat manifest.json | grep id | cut -d '"' -f4`
mv addon.xpi "${EXTENSIONS_SYSTEM}/${ADDON_NAME}.xpi"

chown -R 1000:1000 $HOME/.mozilla/firefox/kasm/
