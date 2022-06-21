#!/usr/bin/env bash
set -ex

CHROME_ARGS="--password-store=basic --no-sandbox  --ignore-gpu-blocklist --user-data-dir --no-first-run --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')

apt-get update
apt-get install -y jq

# This gets tricky because we want the builds from https://www.googleapis.com/storage/v1/b/chromium-browser-snapshots
# so we can get debug symbols, however they don't seem to be available for ARM, so we have to use the original method of
# pulling down an archive 18.04 deb for arm, and use the new method for x64.
if [[ ${ARCH} == "amd64" ]] ;
then
  if [ -z "${CHROMIUM_VERSION}" ]
  then
    # If we are not passed in a Chromium build_id look up latest from Omaha proxy: https://omahaproxy.appspot.com/
    # (commented out to keep in sync with arm version)
    # omaha_data=$(curl https://omahaproxy.appspot.com/json)
    # CHROMIUM_VERSION=$(echo ${omaha_data} | jq '.[] | select(.os=="linux") | .versions | .[] | select(.channel=="stable") | .branch_base_position')

    # This keeps us in sync with the arm version we use on ubuntu:
    chrome_url="http://archive.ubuntu.com/ubuntu/pool/universe/c/chromium-browser/"
    chromium_version=$(curl ${chrome_url})
    chromium_version=$(grep "chromium-browser_" <<< "${chromium_version}")
    chromium_version=$(grep "18\.04" <<< "${chromium_version}")
    chromium_version=$(grep "${ARCH}" <<< "${chromium_version}")
    chromium_version=$(sed -n 's/.*chromium-browser_//p' <<< "${chromium_version}")
    chromium_version=$(sed -n 's/-.ubuntu.*//p' <<< "${chromium_version}")
    omaha_data=$(curl "https://omahaproxy.appspot.com/deps.json?version=${chromium_version}")
    CHROMIUM_VERSION=$(echo "${omaha_data}" | jq -r '.chromium_base_position')

  fi

  # Download chrome at version
  DL_URL=$(curl -sL "https://www.googleapis.com/storage/v1/b/chromium-browser-snapshots/o/Linux_x64%2F${CHROMIUM_VERSION}%2Fchrome-linux.zip" | jq -r '.mediaLink')
  curl -L -o \
    /tmp/chrome.zip \
    "${DL_URL}"
  cd /tmp
  unzip chrome.zip
  mv chrome-linux/* /usr/bin/
  mv /usr/bin/chrome /usr/bin/chrome-orig
  cat >/usr/bin/chrome <<EOL
  #!/usr/bin/env bash
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
  sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences
  if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
      echo "Starting Chrome with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
      vglrun -d "\${KASM_EGL_CARD}" /usr/bin/chrome-orig ${CHROME_ARGS} "\$@"
  else
      echo "Starting Chrome"
      /usr/bin/chrome-orig ${CHROME_ARGS} "\$@"
  fi
EOL
  chmod +x /usr/bin/chrome
  cp /usr/bin/chrome /usr/bin/chromium

  cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/chrome" "${CHROME_ARGS}"  "\$@"
EOL

  mkdir -p /etc/chromium/policies/managed/
  cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
  {"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL

  cat >>$HOME/Desktop/chrome.desktop <<EOL
  [Desktop Entry]
  Version=1.0
  NoDisplay=true
  Name=Chromium Web Browser
  Name[ast]=Restolador web Chromium
  Name[bg]=Уеб четец Chromium
  Name[bn]=ক্রোমিয়াম ওয়েব ব্রাউজার
  Name[bs]=Chromium web preglednik
  Name[ca]=Navegador web Chromium
  Name[ca@valencia]=Navegador web Chromium
  Name[da]=Chromium netbrowser
  Name[de]=Chromium-Webbrowser
  Name[en_AU]=Chromium Web Browser
  Name[eo]=Kromiumo retfoliumilo
  Name[es]=Navegador web Chromium
  Name[et]=Chromiumi veebibrauser
  Name[eu]=Chromium web-nabigatzailea
  Name[fi]=Chromium-selain
  Name[fr]=Navigateur Web Chromium
  Name[gl]=Navegador web Chromium
  Name[he]=דפדפן האינטרנט כרומיום
  Name[hr]=Chromium web preglednik
  Name[hu]=Chromium webböngésző
  Name[hy]=Chromium ոստայն զննարկիչ
  Name[ia]=Navigator del web Chromium
  Name[id]=Peramban Web Chromium
  Name[it]=Browser web Chromium
  Name[ja]=Chromium ウェブ・ブラウザ
  Name[ka]=ვებ ბრაუზერი Chromium
  Name[ko]=Chromium 웹 브라우저
  Name[kw]=Peurel wias Chromium
  Name[ms]=Pelayar Web Chromium
  Name[nb]=Chromium nettleser
  Name[nl]=Chromium webbrowser
  Name[pt_BR]=Navegador de Internet Chromium
  Name[ro]=Navigator Internet Chromium
  Name[ru]=Веб-браузер Chromium
  Name[sl]=Chromium spletni brskalnik
  Name[sv]=Webbläsaren Chromium
  Name[ug]=Chromium توركۆرگۈ
  Name[vi]=Trình duyệt Web Chromium
  Name[zh_CN]=Chromium 网页浏览器
  Name[zh_HK]=Chromium 網頁瀏覽器
  Name[zh_TW]=Chromium 網頁瀏覽器
  GenericName=Web Browser
  GenericName[ar]=متصفح الشبكة
  GenericName[ast]=Restolador web
  GenericName[bg]=Уеб браузър
  GenericName[bn]=ওয়েব ব্রাউজার
  GenericName[bs]=Web preglednik
  GenericName[ca]=Navegador web
  GenericName[ca@valencia]=Navegador web
  GenericName[cs]=WWW prohlížeč
  GenericName[da]=Browser
  GenericName[de]=Web-Browser
  GenericName[el]=Περιηγητής ιστού
  GenericName[en_AU]=Web Browser
  GenericName[en_GB]=Web Browser
  GenericName[eo]=Retfoliumilo
  GenericName[es]=Navegador web
  GenericName[et]=Veebibrauser
  GenericName[eu]=Web-nabigatzailea
  GenericName[fi]=WWW-selain
  GenericName[fil]=Web Browser
  GenericName[fr]=Navigateur Web
  GenericName[gl]=Navegador web
  GenericName[gu]=વેબ બ્રાઉઝર
  GenericName[he]=דפדפן אינטרנט
  GenericName[hi]=वेब ब्राउज़र
  GenericName[hr]=Web preglednik
  GenericName[hu]=Webböngésző
  GenericName[hy]=Ոստայն զննարկիչ
  GenericName[ia]=Navigator del Web
  GenericName[id]=Peramban Web
  GenericName[it]=Browser web
  GenericName[ja]=ウェブ・ブラウザ
  GenericName[ka]=ვებ ბრაუზერი
  GenericName[kn]=ಜಾಲ ವೀಕ್ಷಕ
  GenericName[ko]=웹 브라우저
  GenericName[kw]=Peurel wias
  GenericName[lt]=Žiniatinklio naršyklė
  GenericName[lv]=Tīmekļa pārlūks
  GenericName[ml]=വെബ് ബ്രൌസര്‍
  GenericName[mr]=वेब ब्राऊजर
  GenericName[ms]=Pelayar Web
  GenericName[nb]=Nettleser
  GenericName[nl]=Webbrowser
  GenericName[or]=ଓ୍ବେବ ବ୍ରାଉଜର
  GenericName[pl]=Przeglądarka WWW
  GenericName[pt]=Navegador Web
  GenericName[pt_BR]=Navegador web
  GenericName[ro]=Navigator de Internet
  GenericName[ru]=Веб-браузер
  GenericName[sk]=WWW prehliadač
  GenericName[sl]=Spletni brskalnik
  GenericName[sr]=Интернет прегледник
  GenericName[sv]=Webbläsare
  GenericName[ta]=இணைய உலாவி
  GenericName[te]=మహాతల అన్వేషి
  GenericName[th]=เว็บเบราว์เซอร์
  GenericName[tr]=Web Tarayıcı
  GenericName[ug]=توركۆرگۈ
  GenericName[uk]=Навігатор Тенет
  GenericName[vi]=Bộ duyệt Web
  GenericName[zh_CN]=网页浏览器
  GenericName[zh_HK]=網頁瀏覽器
  GenericName[zh_TW]=網頁瀏覽器
  Comment=Access the Internet
  Comment[ar]=الدخول إلى الإنترنت
  Comment[ast]=Accesu a Internet
  Comment[bg]=Достъп до интернет
  Comment[bn]=ইন্টারনেটে প্রবেশ করুন
  Comment[bs]=Pristup internetu
  Comment[ca]=Accediu a Internet
  Comment[ca@valencia]=Accediu a Internet
  Comment[cs]=Přístup k internetu
  Comment[da]=Få adgang til internettet
  Comment[de]=Internetzugriff
  Comment[el]=Πρόσβαση στο Διαδίκτυο
  Comment[en_AU]=Access the Internet
  Comment[en_GB]=Access the Internet
  Comment[eo]=Akiri interreton
  Comment[es]=Acceda a Internet
  Comment[et]=Pääs Internetti
  Comment[eu]=Sartu Internetera
  Comment[fi]=Käytä internetiä
  Comment[fil]=I-access ang Internet
  Comment[fr]=Accéder à Internet
  Comment[gl]=Acceda a Internet
  Comment[gu]=ઇંટરનેટ ઍક્સેસ કરો
  Comment[he]=גישה לאינטרנט
  Comment[hi]=इंटरनेट तक पहुंच स्थापित करें
  Comment[hr]=Pristupite Internetu
  Comment[hu]=Az internet elérése
  Comment[hy]=Մուտք համացանց
  Comment[ia]=Accede a le Interrete
  Comment[id]=Akses Internet
  Comment[it]=Accesso a Internet
  Comment[ja]=インターネットにアクセス
  Comment[ka]=ინტერნეტში შესვლა
  Comment[kn]=ಇಂಟರ್ನೆಟ್ ಅನ್ನು ಪ್ರವೇಶಿಸಿ
  Comment[ko]=인터넷에 연결합니다
  Comment[kw]=Hedhes an Kesrosweyth
  Comment[lt]=Interneto prieiga
  Comment[lv]=Piekļūt internetam
  Comment[ml]=ഇന്റര്‍‌നെറ്റ് ആക്‌സസ് ചെയ്യുക
  Comment[mr]=इंटरनेटमध्ये प्रवेश करा
  Comment[ms]=Mengakses Internet
  Comment[nb]=Bruk internett
  Comment[nl]=Verbinding maken met internet
  Comment[or]=ଇଣ୍ଟର୍ନେଟ୍ ପ୍ରବେଶ କରନ୍ତୁ
  Comment[pl]=Skorzystaj z internetu
  Comment[pt]=Aceder à Internet
  Comment[pt_BR]=Acessar a internet
  Comment[ro]=Accesați Internetul
  Comment[ru]=Доступ в Интернет
  Comment[sk]=Prístup do siete Internet
  Comment[sl]=Dostop do interneta
  Comment[sr]=Приступите Интернету
  Comment[sv]=Surfa på Internet
  Comment[ta]=இணையத்தை அணுகுதல்
  Comment[te]=ఇంటర్నెట్‌ను ఆక్సెస్ చెయ్యండి
  Comment[th]=เข้าถึงอินเทอร์เน็ต
  Comment[tr]=İnternet'e erişin
  Comment[ug]=ئىنتېرنېت زىيارىتى
  Comment[uk]=Доступ до Інтернету
  Comment[vi]=Truy cập Internet
  Comment[zh_CN]=访问互联网
  Comment[zh_HK]=連線到網際網路
  Comment[zh_TW]=連線到網際網路
  Exec=chromium-browser %U
  Terminal=false
  X-MultipleArgs=false
  Type=Application
  Icon=chromium-browser
  Categories=Network;WebBrowser;
  StartupNotify=true
  Actions=NewWindow;Incognito;TempProfile;
  X-AppInstall-Package=chromium-browser

  [Desktop Action NewWindow]
  Name=Open a New Window
  Name[ast]=Abrir una Ventana Nueva
  Name[bg]=Отваряне на Нов прозорец
  Name[bn]=একটি নতুন উইন্ডো খুলুন
  Name[bs]=Otvori novi prozor
  Name[ca]=Obre una finestra nova
  Name[ca@valencia]=Obri una finestra nova
  Name[da]=Åbn et nyt vindue
  Name[de]=Ein neues Fenster öffnen
  Name[en_AU]=Open a New Window
  Name[eo]=Malfermi novan fenestron
  Name[es]=Abrir una ventana nueva
  Name[et]=Ava uus aken
  Name[eu]=Ireki leiho berria
  Name[fi]=Avaa uusi ikkuna
  Name[fr]=Ouvrir une nouvelle fenêtre
  Name[gl]=Abrir unha nova xanela
  Name[he]=פתיחת חלון חדש
  Name[hy]=Բացել նոր պատուհան
  Name[ia]=Aperi un nove fenestra
  Name[it]=Apri una nuova finestra
  Name[ja]=新しいウィンドウを開く
  Name[ka]=ახალი ფანჯრის გახსნა
  Name[kw]=Egery fenester noweth
  Name[ms]=Buka Tetingkap Baru
  Name[nb]=Åpne et nytt vindu
  Name[nl]=Nieuw venster openen
  Name[pt_BR]=Abre uma nova janela
  Name[ro]=Deschide o fereastră nouă
  Name[ru]=Открыть новое окно
  Name[sl]=Odpri novo okno
  Name[sv]=Öppna ett nytt fönster
  Name[ug]=يېڭى كۆزنەك ئاچ
  Name[uk]=Відкрити нове вікно
  Name[vi]=Mở cửa sổ mới
  Name[zh_CN]=打开新窗口
  Name[zh_TW]=開啟新視窗
  Exec=chromium-browser

  [Desktop Action Incognito]
  Name=Open a New Window in incognito mode
  Name[ast]=Abrir una ventana nueva en mou incógnitu
  Name[bg]=Отваряне на нов прозорец в режим \"инкогнито\"
  Name[bn]=একটি নতুন উইন্ডো খুলুন ইনকোগনিটো অবস্থায়
  Name[bs]=Otvori novi prozor u privatnom modu
  Name[ca]=Obre una finestra nova en mode d'incògnit
  Name[ca@valencia]=Obri una finestra nova en mode d'incògnit
  Name[de]=Ein neues Fenster im Inkognito-Modus öffnen
  Name[en_AU]=Open a New Window in incognito mode
  Name[eo]=Malfermi novan fenestron nekoniĝeble
  Name[es]=Abrir una ventana nueva en modo incógnito
  Name[et]=Ava uus aken tundmatus olekus
  Name[eu]=Ireki leiho berria isileko moduan
  Name[fi]=Avaa uusi ikkuna incognito-tilassa
  Name[fr]=Ouvrir une nouvelle fenêtre en mode navigation privée
  Name[gl]=Abrir unha nova xanela en modo de incógnito
  Name[he]=פתיחת חלון חדש במצב גלישה בסתר
  Name[hy]=Բացել նոր պատուհան ծպտյալ աշխատակերպում
  Name[ia]=Aperi un nove fenestra in modo incognite
  Name[it]=Apri una nuova finestra in modalità incognito
  Name[ja]=新しいシークレット ウィンドウを開く
  Name[ka]=ახალი ფანჯრის ინკოგნიტოდ გახსნა
  Name[kw]=Egry fenester noweth en modh privedh
  Name[ms]=Buka Tetingkap Baru dalam mod menyamar
  Name[nl]=Nieuw venster openen in incognito-modus
  Name[pt_BR]=Abrir uma nova janela em modo anônimo
  Name[ro]=Deschide o fereastră nouă în mod incognito
  Name[ru]=Открыть новое окно в режиме инкогнито
  Name[sl]=Odpri novo okno v načinu brez beleženja
  Name[sv]=Öppna ett nytt inkognitofönster
  Name[ug]=يوشۇرۇن ھالەتتە يېڭى كۆزنەك ئاچ
  Name[uk]=Відкрити нове вікно у приватному режимі
  Name[vi]=Mở cửa sổ mới trong chế độ ẩn danh
  Name[zh_CN]=以隐身模式打开新窗口
  Name[zh_TW]=以匿名模式開啟新視窗
  Exec=chromium-browser --incognito

  [Desktop Action TempProfile]
  Name=Open a New Window with a temporary profile
  Name[ast]=Abrir una ventana nueva con perfil temporal
  Name[bg]=Отваряне на Нов прозорец с временен профил
  Name[bn]=সাময়িক প্রোফাইল সহ একটি নতুন উইন্ডো খুলুন
  Name[bs]=Otvori novi prozor pomoću privremenog profila
  Name[ca]=Obre una finestra nova amb un perfil temporal
  Name[ca@valencia]=Obri una finestra nova amb un perfil temporal
  Name[de]=Ein neues Fenster mit einem temporären Profil öffnen
  Name[en_AU]=Open a New Window with a temporary profile
  Name[eo]=Malfermi novan fenestron portempe
  Name[es]=Abrir una ventana nueva con perfil temporal
  Name[et]=Ava uus aken ajutise profiiliga
  Name[eu]=Ireki leiho berria behin-behineko profil batekin
  Name[fi]=Avaa uusi ikkuna käyttäen väliaikaista profiilia
  Name[fr]=Ouvrir une nouvelle fenêtre avec un profil temporaire
  Name[gl]=Abrir unha nova xanela con perfil temporal
  Name[he]=פתיחת חלון חדש עם פרופיל זמני
  Name[hy]=Բացել նոր պատուհան ժամանակավոր հատկագրով
  Name[ia]=Aperi un nove fenestra con un profilo provisori
  Name[it]=Apri una nuova finestra con un profilo temporaneo
  Name[ja]=一時プロファイルで新しいウィンドウを開く
  Name[ka]=ახალი ფანჯრის გახსნა დროებით პროფილში
  Name[kw]=Egery fenester noweth gen profil dres prys
  Name[ms]=Buka Tetingkap Baru dengan profil sementara
  Name[nb]=Åpne et nytt vindu med en midlertidig profil
  Name[nl]=Nieuw venster openen met een tijdelijk profiel
  Name[pt_BR]=Abrir uma nova janela com um perfil temporário
  Name[ro]=Deschide o fereastră nouă cu un profil temporar
  Name[ru]=Открыть новое окно с временным профилем
  Name[sl]=Odpri novo okno z začasnim profilom
  Name[sv]=Öppna ett nytt fönster med temporär profil
  Name[ug]=ۋاقىتلىق سەپلىمە ھۆججەت بىلەن يېڭى كۆزنەك ئاچ
  Name[vi]=Mở cửa sổ mới với hồ sơ tạm
  Name[zh_CN]=以临时配置文件打开新窗口
  Name[zh_TW]=以暫時性個人身分開啟新視窗
  Exec=chromium-browser --temp-profile
EOL
  chown 1000:1000 $HOME/Desktop/chrome.desktop

  # Cleanup
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

else
  # Chromium on Ubuntu 19.10 or newer uses snap to install which is not
  # currently compatible with docker containers. The new install will pull
  # deb files from archive.ubuntu.com for ubuntu 18.04 and install them.
  # This will work until 18.04 goes to an unsupported status.
  chrome_url="http://ports.ubuntu.com/pool/universe/c/chromium-browser/"
  chromium_codecs_data=$(curl ${chrome_url})
  chromium_codecs_data=$(grep "chromium-codecs-ffmpeg-extra_" <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(grep "18\.04" <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(grep "${ARCH}" <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(sed -n 's/.*<a href="//p' <<< "${chromium_codecs_data}")
  chromium_codecs_data=$(sed -n 's/">.*//p' <<< "${chromium_codecs_data}")
  echo "Chromium codec deb to download: ${chromium_codecs_data}"

  chromium_data=$(curl ${chrome_url})
  chromium_data=$(grep "chromium-browser_" <<< "${chromium_data}")
  chromium_data=$(grep "18\.04" <<< "${chromium_data}")
  chromium_data=$(grep "${ARCH}" <<< "${chromium_data}")
  chromium_data=$(sed -n 's/.*<a href="//p' <<< "${chromium_data}")
  chromium_data=$(sed -n 's/">.*//p' <<< "${chromium_data}")
  echo "Chromium browser deb to download: ${chromium_data}"

  echo "The things to download"
  echo "${chrome_url}${chromium_codecs_data}"
  echo "${chrome_url}${chromium_data}"

  wget "${chrome_url}${chromium_codecs_data}"
  wget "${chrome_url}${chromium_data}"

  apt-get install -y ./"${chromium_codecs_data}"
  apt-get install -y ./"${chromium_data}"

  rm "${chromium_codecs_data}"
  rm "${chromium_data}"
  sed -i 's/-stable//g' /usr/share/applications/chromium-browser.desktop

  cp /usr/share/applications/chromium-browser.desktop $HOME/Desktop/
  chown 1000:1000 $HOME/Desktop/chromium-browser.desktop

  mv /usr/bin/chromium-browser /usr/bin/chromium-browser-orig
  cat >/usr/bin/chromium-browser <<EOL
  #!/usr/bin/env bash
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
  sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/chromium/Default/Preferences
  if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
      echo "Starting Chrome with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
      vglrun -d "\${KASM_EGL_CARD}" /usr/bin/chromium-browser-orig ${CHROME_ARGS} "\$@"
  else
      echo "Starting Chrome"
      /usr/bin/chromium-browser-orig ${CHROME_ARGS} "\$@"
  fi
EOL
  chmod +x /usr/bin/chromium-browser
  cp /usr/bin/chromium-browser /usr/bin/chromium
  sed -i 's@exec -a "$0" "$HERE/chromium" "$\@"@@g' /usr/bin/x-www-browser
  cat >>/usr/bin/x-www-browser <<EOL
  exec -a "\$0" "\$HERE/chromium" "${CHROME_ARGS}"  "\$@"
EOL
  mkdir -p /etc/chromium/policies/managed/
  cat >>/etc/chromium/policies/managed/default_managed_policy.json <<EOL
  {"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
fi