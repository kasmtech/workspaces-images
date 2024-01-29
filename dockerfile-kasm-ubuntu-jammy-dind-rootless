ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-jammy"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG
USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

# Rootless Dind
ENV DOCKER_BIN=/usr/local/lib/docker \
    XDG_RUNTIME_DIR=/docker 
RUN mkdir -p $DOCKER_BIN && chown 1000:0 $DOCKER_BIN && \
    mkdir -p $XDG_RUNTIME_DIR && chown 1000:0 $XDG_RUNTIME_DIR
ENV PATH=$DOCKER_BIN:$DOCKER_BIN/cli-plugins:$PATH \
        DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
COPY ./src/ubuntu/install/dind_rootless/install_dind_rootless_prerequisites.sh $INST_SCRIPTS/dind_rootless/
RUN bash $INST_SCRIPTS/dind_rootless/install_dind_rootless_prerequisites.sh
COPY ./src/ubuntu/install/dind_rootless/install_dind_rootless.sh $INST_SCRIPTS/dind_rootless/
RUN chown 1000:1000 $INST_SCRIPTS/dind_rootless/install_dind_rootless.sh
# It's recommended that docker-rootless be installed by non root user
USER 1000
RUN bash $INST_SCRIPTS/dind_rootless/install_dind_rootless.sh
USER root
RUN rm -rf $INST_SCRIPTS/dind_rootless
COPY ./src/ubuntu/install/dind_rootless/custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh && chmod 755 $STARTUPDIR/custom_startup.sh
COPY ./src/ubuntu/install/dind_rootless/modprobe /usr/local/bin/modprobe
RUN chmod +x /usr/local/bin/modprobe

### Envrionment config
ENV DEBIAN_FRONTEND=noninteractive \
    SKIP_CLEAN=true \
    KASM_RX_HOME=$STARTUPDIR/kasmrx \
    DONT_PROMPT_WSL_INSTALL="No_Prompt_please" \
    INST_DIR=$STARTUPDIR/install \
    INST_SCRIPTS="/ubuntu/install/tools/install_tools_deluxe.sh \
                  /ubuntu/install/misc/install_tools.sh \
                  /ubuntu/install/chrome/install_chrome.sh \
                  /ubuntu/install/chromium/install_chromium.sh \
                  /ubuntu/install/sublime_text/install_sublime_text.sh \
                  /ubuntu/install/vs_code/install_vs_code.sh \
                  /ubuntu/install/cleanup/cleanup.sh"

# Copy install scripts
COPY ./src/ $INST_DIR

# Run installations
RUN \
  for SCRIPT in $INST_SCRIPTS; do \
    bash ${INST_DIR}${SCRIPT} || exit 1; \
  done && \
  $STARTUPDIR/set_user_permission.sh $HOME && \
  rm -f /etc/X11/xinit/Xclients && \
  chown 1000:0 $HOME && \
  mkdir -p /home/kasm-user && \
  chown -R 1000:0 /home/kasm-user && \
  rm -Rf ${INST_DIR}

# Userspace Runtime
ENV HOME /home/kasm-user
WORKDIR $HOME
USER 1000

CMD ["--tail-log"]
