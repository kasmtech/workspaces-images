EXEC_THEMIS = Themis
EXEC_LIB_RANA = librana.so
LAUNCHER_THEMIS = launcher

kible-firefox-arm-publish: $(EXEC_THEMIS) $(EXEC_LIB_RANA) $(LAUNCHER_THEMIS)
	docker build --platform linux/arm64 --file dockerfile-kasm-firefox-arm -t kible/firefox:arm .
	docker login -u "kible" -p "eehKgVR4QmoED8" docker.io
	docker push kible/firefox:arm

kible-firefox-x86-publish: $(EXEC_THEMIS) $(EXEC_LIB_RANA) $(LAUNCHER_THEMIS)
	docker build --platform linux/amd64 --file dockerfile-kasm-firefox-x86 -t kible/firefox:x86 .
	docker login -u "kible" -p "eehKgVR4QmoED8" docker.io
	docker push kible/firefox:x86

$(EXEC_LIB_RANA):
	cp ../Rana_Core_Utils/Rana_Core_Utils/librana.so ./

$(EXEC_THEMIS):
	cp ../Themis/Themis/Themis ./

$(LAUNCHER_THEMIS):
	cp ../Themis/Themis/launcher ./