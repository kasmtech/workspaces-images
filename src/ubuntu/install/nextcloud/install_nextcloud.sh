#!/usr/bin/env bash
set -ex
if [[ "${DISTRO}" == @(oracle8|rockylinux9|rockylinux8|oracle9|rhel9|almalinux9|almalinux8) ]]; then
  dnf install -y nextcloud-client
  if [ -z ${SKIP_CLEAN+x} ]; then
    dnf clean all
  fi
elif [ "${DISTRO}" == "opensuse" ]; then
  zypper install -yn nextcloud-desktop
  if [ -z ${SKIP_CLEAN+x} ]; then
    zypper clean --all
  fi
elif grep -q "ID=debian" /etc/os-release; then
  apt-get update
  apt-get install -y nextcloud-desktop
  if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get autoclean
    rm -rf \
      /var/lib/apt/lists/* \
      /var/tmp/*
  fi
else
  apt-get install -y software-properties-common
  add-apt-repository -y ppa:nextcloud-devs/client
  apt update
  apt install -y nextcloud-desktop
  if [ -z ${SKIP_CLEAN+x} ]; then
    apt-get autoclean
    rm -rf \
      /var/lib/apt/lists/* \
      /var/tmp/*
  fi
fi

cat >$HOME/Desktop/nextcloud.desktop  <<EOL
[Desktop Entry]
Categories=Utility;X-SuSE-SyncUtility;
Type=Application
Exec=nextcloud
Name=Nextcloud desktop sync client
Comment=Nextcloud desktop synchronization client
GenericName=Folder Sync
Icon=Nextcloud
Keywords=Nextcloud;syncing;file;sharing;
X-GNOME-Autostart-Delay=3
# Translations
Comment[oc]=Nextcloud sincronizacion del client
GenericName[oc]=Dorsièr de Sincronizacion
Name[oc]=Nextcloud sincronizacion del client
Icon[oc]=Nextcloud
Comment[ar]=Nextcloud زبون مزامنة مكتبي
GenericName[ar]=مزامنة المجلد
Name[ar]=Nextcloud زبون مزامنة مكتبي
Icon[ar]=Nextcloud
Comment[bg_BG]=Nextcloud клиент за десктоп синхронизация
GenericName[bg_BG]=Синхронизиране на папката
Name[bg_BG]=Nextcloud клиент десктоп синхронизация
Icon[bg_BG]=Nextcloud
Comment[ca]=Client de sincronització d'escriptori Nextcloud
GenericName[ca]=Sincronització de carpetes
Name[ca]=Client de sincronització d'escriptori Nextcloud
Icon[ca]=Nextcloud
Comment[da]=Nextcloud skrivebordsklient til synkronisering
GenericName[da]=Mappesynkronisering
Name[da]=Nextcloud skrivebordsklient til synk
Icon[da]=Nextcloud
Comment[de]=Nextcloud Desktop-Synchronisationsclient
GenericName[de]=Ordner-Synchronisation
Name[de]=Nextcloud Desktop-Synchronisationsclient
Icon[de]=Nextcloud
Comment[ja_JP]=Nextcloud デスクトップ同期クライアント
GenericName[ja_JP]=フォルダー同期
Name[ja_JP]=Nextcloud デスクトップ同期クライアント
Icon[ja_JP]=Nextcloud
Comment[el]=@ΟΝΟΜΑ_ΕΦΑΡΜΟΓΗΣ@ συγχρονισμός επιφάνειας εργασίας πελάτη
GenericName[el]=Συγχρονισμός φακέλου
Name[el]=@ΟΝΟΜΑ_ΕΦΑΡΜΟΓΗΣ@  συγχρονισμός επιφάνειας εργασίας πελάτη
Icon[el]=Nextcloud
Comment[en_GB]=Nextcloud desktop synchronisation client
GenericName[en_GB]=Folder Sync
Name[en_GB]=Nextcloud desktop sync client
Icon[en_GB]=Nextcloud
Comment[es]=Nextcloud cliente de sincronización de escritorio
GenericName[es]=Sincronización de carpeta
Name[es]=Nextcloud cliente de sincronización de escritorio
Icon[es]=Nextcloud
Comment[de_DE]=Nextcloud Desktop-Synchronisationsclient
GenericName[de_DE]=Ordner-Synchronisation
Name[de_DE]=Nextcloud Desktop-Synchronisationsclient
Icon[de_DE]=Nextcloud
Comment[eu]=Nextcloud mahaigaineko sinkronizazio bezeroa
GenericName[eu]=Karpetaren sinkronizazioa
Name[eu]=Nextcloud mahaigaineko sinkronizazio bezeroa
Icon[eu]=Nextcloud
GenericName[fa]=همسان سازی پوشه‌ها
Name[fa]=nextcloud نسخه‌ی همسان سازی مشتری
Icon[fa]=Nextcloud
Comment[fr]=Synchronisez vos dossiers avec un serveur Nextcloud
GenericName[fr]=Synchronisation de dossier
Name[fr]=Client de synchronisation Nextcloud
Icon[fr]=Nextcloud
Comment[gl]=Nextcloud cliente de sincronización para escritorio
GenericName[gl]=Sincronizar Cartafol
Name[gl]=Nextcloud cliente de sincronización para escritorio
Icon[gl]=Nextcloud
Comment[he]=Nextcloud לקוח סנכון שולחן עבודה
GenericName[he]=סנכון תיקייה
Name[he]=Nextcloud לקוח סנכרון שולחן עבודה
Icon[he]=Nextcloud
Comment[ia]=Nextcloud cliente de synchronisation pro scriptorio
GenericName[ia]=Synchronisar Dossier
Name[ia]=Nextcloud cliente de synchronisation pro scriptorio
Icon[ia]=Nextcloud
Comment[id]=Klien sinkronisasi desktop Nextcloud
GenericName[id]=Folder Sync
Name[id]=Klien sync desktop Nextcloud
Icon[id]=Nextcloud
Comment[is]=Nextcloud skjáborðsforrit samstillingar
GenericName[is]=Samstilling möppu
Name[is]=Nextcloud skjáborðsforrit samstillingar
Icon[is]=Nextcloud
Comment[it]=Client di sincronizzazione del desktop di Nextcloud
GenericName[it]=Sincronizzazione cartella
Name[it]=Client di sincronizzazione del desktop di Nextcloud
Icon[it]=Nextcloud
Comment[ko]=Nextcloud 데스크톱 동기화 클라이언트
GenericName[ko]=폴더 동기화
Name[ko]=Nextcloud 데스크톱 동기화 클라이언트
Icon[ko]=Nextcloud
Comment[hu_HU]=Nextcloud asztali szinkronizációs kliens
GenericName[hu_HU]=Könyvtár szinkronizálás
Name[hu_HU]=Nextcloud asztali szinkr. kliens
Icon[hu_HU]=Nextcloud
Comment[af_ZA]=Nextcloud werkskermsinchroniseerkliënt
GenericName[af_ZA]=Vouersinchronisering
Name[af_ZA]=Nextcloud werkskermsinchroniseerkliënt
Icon[af_ZA]=Nextcloud
Comment[nl]=Nextcloud desktop synchronisatie client
GenericName[nl]=Mappen sync
Name[nl]=Nextcloud desktop sync client
Icon[nl]=Nextcloud
Comment[et_EE]=Nextcloud sünkroonimise klient töölauale
GenericName[et_EE]=Kaustade sünkroonimine
Name[et_EE]=Nextcloud sünkroonimise klient töölauale
Icon[et_EE]=Nextcloud
Comment[pl]=Nextcloud klient synchronizacji dla komputerów stacjonarnych
GenericName[pl]=Folder Synchronizacji
Name[pl]=Nextcloud klient synchronizacji dla komputerów stacjonarnych
Icon[pl]=Nextcloud
Comment[pt_BR]=Nextcloud cliente de sincronização do computador
GenericName[pt_BR]=Sincronização de Pasta
Name[pt_BR]=Nextcloud cliente de sincronização de desktop
Icon[pt_BR]=Nextcloud
Comment[cs_CZ]=Nextcloud počítačový synchronizační klient
GenericName[cs_CZ]=Synchronizace adresáře
Name[cs_CZ]=Nextcloud počítačový synchronizační klient
Icon[cs_CZ]=Nextcloud
Comment[ru]=Настольный клиент синхронизации Nextcloud
GenericName[ru]=Синхронизация каталогов
Name[ru]=Настольный клиент синхронизации Nextcloud
Icon[ru]=Nextcloud
Comment[sl]=Nextcloud ‒ Program za usklajevanje datotek z namizjem
GenericName[sl]=Usklajevanje map
Name[sl]=Nextcloud ‒ Program za usklajevanje datotek z namizjem
Icon[sl]=Nextcloud
Comment[sq]=Klient njëkohësimesh Nextcloud për desktop
GenericName[sq]=Njëkohësim Dosjesh
Name[sq]=Klient njëkohësimesh Nextcloud për desktop
Icon[sq]=Nextcloud
Comment[fi_FI]=Nextcloud työpöytäsynkronointisovellus
GenericName[fi_FI]=Kansion synkronointi
Name[fi_FI]=Nextcloud työpöytäsynkronointisovellus
Icon[fi_FI]=Nextcloud
Comment[sv]=Nextcloud desktop synkroniseringsklient
GenericName[sv]=Mappsynk
Name[sv]=Nextcloud desktop synk-klient
Icon[sv]=Nextcloud
Comment[tr]=Nextcloud masaüstü eşitleme istemcisi
GenericName[tr]=Dosya Eşitleme
Name[tr]=Nextcloud masaüstü eşitleme istemcisi
Icon[tr]=Nextcloud
Comment[uk]=Настільний клієнт синхронізації Nextcloud
GenericName[uk]=Синхронізація теки
Name[uk]=Настільний клієнт синхронізації Nextcloud
Icon[uk]=Nextcloud
Comment[ro]=Nextcloud client de sincronizare pe desktop
GenericName[ro]=Sincronizare director
Name[ro]=Nextcloud client de sincronizare pe desktop
Icon[ro]=Nextcloud
Comment[zh_CN]=Nextcloud 桌面同步客户端
GenericName[zh_CN]=文件夹同步
Name[zh_CN]=Nextcloud 桌面同步客户端
Icon[zh_CN]=Nextcloud
Comment[zh_HK]=桌面版同步客户端
Comment[zh_TW]=Nextcloud 桌面同步客戶端
GenericName[zh_TW]=資料夾同步
Name[zh_TW]=Nextcloud 桌面同步客戶端
Icon[zh_TW]=Nextcloud
Comment[es_AR]=Cliente de sincronización para escritorio Nextcloud
GenericName[es_AR]=Sincronización de directorio
Name[es_AR]=Cliente de sincronización para escritorio Nextcloud
Icon[es_AR]=Nextcloud
Comment[lt_LT]=Nextcloud darbalaukio sinchronizavimo programa
GenericName[lt_LT]=Katalogo sinchnorizacija
Name[lt_LT]=Nextcloud darbalaukio programa
Icon[lt_LT]=Nextcloud
Comment[th_TH]=Nextcloud ไคลเอนต์ประสานข้อมูลเดสก์ท็อป
GenericName[th_TH]=ประสานข้อมูลโฟลเดอร์
Name[th_TH]= Nextcloud ไคลเอนต์ประสานข้อมูลเดสก์ท็อป
Icon[th_TH]=Nextcloud
Comment[es_MX]=Cliente de escritorio para  sincronziación de Nextcloud
GenericName[es_MX]=Sincronización de Carpetas
Name[es_MX]=Cliente de escritorio para  sincronziación de Nextcloud
Icon[es_MX]=Nextcloud
Comment[nb_NO]=Nextcloud skrivebordssynkroniseringsklient
GenericName[nb_NO]=Mappesynkronisering
Name[nb_NO]=Nextcloud skrivebordssynkroniseringsklient
Icon[nb_NO]=Nextcloud
Comment[nn_NO]=Nextcloud klient for å synkronisera frå skrivebord
GenericName[nn_NO]=Mappe synkronisering
Name[nn_NO]=Nextcloud klient for å synkronisera frå skrivebord
Icon[nn_NO]=Nextcloud
Comment[pt_PT]=Nextcloud - Cliente de Sincronização para PC
GenericName[pt_PT]=Sincronizar Pasta
Name[pt_PT]=Nextcloud - Cliente de Sincronização para PC
Icon[pt_PT]=Nextcloud
Icon[km]=Nextcloud
Comment[lb]=Nextcloud Desktop Synchronisatioun Client
GenericName[lb]=Dossier Dync
Name[lb]=Nextcloud Desktop Sync Client
Icon[lb]=Nextcloud

EOL

chown -R 1000:0 $HOME/Desktop/nextcloud.desktop
