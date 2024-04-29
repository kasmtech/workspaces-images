ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "amd64" ] ; then
    bash ${INST_DIR}/ubuntu/install/chrome/install_chrome.sh

    # Remove default app launchers
    rm -f $HOME/Desktop/google-chrome.desktop
    rm -f /usr/share/applications/browser.desktop
    mv /usr/share/applications/google-chrome.desktop /usr/share/applications/browser.desktop
else
    bash ${INST_DIR}/ubuntu/install/chromium/install_chromium.sh

    rm -f $HOME/Desktop/chromium.desktop
    rm -f /usr/share/applications/browser.desktop
    mv /usr/share/applications/chromium.desktop /usr/share/applications/browser.desktop

fi