ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-focal"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG

USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
WORKDIR $HOME

### Envrionment config
ENV DEBIAN_FRONTEND noninteractive
ENV KASM_RX_HOME $STARTUPDIR/kasmrx
ENV INST_SCRIPTS $STARTUPDIR/install


### Install Tools
COPY ./src/ubuntu/install/tools $INST_SCRIPTS/tools/
RUN bash $INST_SCRIPTS/tools/install_tools_deluxe.sh  && rm -rf $INST_SCRIPTS/tools/

# Install Utilities
COPY ./src/ubuntu/install/misc $INST_SCRIPTS/misc/
RUN bash $INST_SCRIPTS/misc/install_tools.sh && rm -rf $INST_SCRIPTS/misc/

# Install Google Chrome
COPY ./src/ubuntu/install/chrome $INST_SCRIPTS/chrome/
RUN bash $INST_SCRIPTS/chrome/install_chrome.sh  && rm -rf $INST_SCRIPTS/chrome/

### Install Sublime Text
COPY ./src/ubuntu/install/sublime_text $INST_SCRIPTS/sublime_text/
RUN bash $INST_SCRIPTS/sublime_text/install_sublime_text.sh  && rm -rf $INST_SCRIPTS/sublime_text/

### Install WINE
COPY ./src/ubuntu/install/wine $INST_SCRIPTS/wine/
RUN bash $INST_SCRIPTS/wine/install_wine.sh  && rm -rf $INST_SCRIPTS/wine/

#ADD ./src/common/scripts $STARTUPDIR
RUN $STARTUPDIR/set_user_permission.sh $HOME

RUN chown 1000:0 $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000

CMD ["--tail-log"]
