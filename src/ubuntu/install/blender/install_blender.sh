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
    BLENDER_VERSION=$(curl -sL https://mirror.clarkson.edu/blender/source/ \
    | awk -F'"|/"' '/blender-[0-9]*\.[0-9]*\.[0-9]*\.tar\.xz/ && !/md5sum/ {print $2}' \
    | tail -1 \
    | sed 's|blender-||' \
    | sed 's|\.tar\.xz||')
fi
BLENDER_FOLDER=$(echo "Blender${BLENDER_VERSION}" | sed -r 's|(Blender[0-9]*\.[0-9]*)\.[0-9]*|\1|')
curl -o /tmp/blender.tar.xz -L "https://mirror.clarkson.edu/blender/release/${BLENDER_FOLDER}/blender-${BLENDER_VERSION}-linux-x64.tar.xz"
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
