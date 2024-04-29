ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
if [ "$ARCH" == "amd64" ] ; then
    bash ${INST_DIR}/ubuntu/install/only_office/install_only_office.sh

    # Remove default app launchers
    rm -f $HOME/Desktop/onlyoffice-desktopeditors.desktop
    rm -f /usr/share/applications/onlyoffice-desktopeditors.desktop

    cp ${INST_DIR}/kasmos/resources/onlyoffice/*.desktop /usr/share/applications/
else
    apt update
    apt install -y libreoffice-plasma
fi