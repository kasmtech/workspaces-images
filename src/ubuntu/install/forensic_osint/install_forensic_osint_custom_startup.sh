#!/bin/bash

set -ex

cp $INST_DIR/ubuntu/install/forensic_osint/custom_startup.sh  $STARTUPDIR/custom_startup.sh
chmod +x $STARTUPDIR/custom_startup.sh
