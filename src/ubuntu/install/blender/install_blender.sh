#!/usr/bin/env bash
set -ex

# If you require a specific version of Blender - rather than the latest - it can be
# hardcoded by setting this variable and rebuilding the container.
#BLENDER_VERSION="3.2.1"

apt-get update
apt-get install --no-install-recommends -y ocl-icd-libopencl1 \
	        xz-utils curl wget nano \
		bzip2 libfreetype6 libgl1-mesa-dev \
		libglu1-mesa \
		libxi6 libxrender1
apt-get -y autoremove
ln -s libOpenCL.so.1 /usr/lib/x86_64-linux-gnu/libOpenCL.so

mkdir /blender
if [ -z ${BLENDER_VERSION+x} ]
then
    BLENDER_VERSION=$(curl -sL https://mirrors.iu13.net/blender/source/ \
    | awk -F'"|/"' '/blender-[0-9]*\.[0-9]*\.[0-9]*\.tar\.xz/ && !/md5sum/ {print $8}' \
    | tail -1 \
    | sed 's|blender-||' \
    | sed 's|\.tar\.xz||');
fi
BLENDER_FOLDER=$(echo "Blender${BLENDER_VERSION}" | sed -r 's|(Blender[0-9]*\.[0-9]*)\.[0-9]*|\1|')
curl -o /tmp/blender.tar.xz -L "https://mirrors.iu13.net/blender/release/${BLENDER_FOLDER}/blender-${BLENDER_VERSION}-linux-x64.tar.xz"
tar xf /tmp/blender.tar.xz -C /blender/ --strip-components=1

cat >/usr/bin/blender <<EOF
#!/usr/bin/env bash
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "\${KASM_EGL_CARD}" ] && [ ! -z "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ]
then
    echo "Starting Blender with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /blender/blender "\$@"
else
    echo "Starting Blender"
    /blender/blender "\$@"
fi
EOF
chmod +x /usr/bin/blender

rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# Desktop icon
sed -i 's#Icon=blender#Icon=/blender/blender.svg#g' /blender/blender.desktop
cp /blender/blender.desktop /usr/share/applications/
cp /usr/share/applications/blender.desktop $HOME/Desktop/
chmod +x $HOME/Desktop/blender.desktop

# Cleanup for app layer
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
if [ -z ${SKIP_CLEAN+x} ]; then
  apt-get autoclean
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*
fi
