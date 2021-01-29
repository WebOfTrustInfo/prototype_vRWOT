#!/bin/bash

# <UDF name="subdomain" label="Subdomain to contain rwot and rwot-login" example="Example: game.my-domain.com"/>
# SUBDOMAIN=
# <UDF name="userpassword" label="Deployment User Password" example="Password for various accounts and infrastructure." />
# USERPASSWORD=
# <UDF name="rwot_skotos_git_url" label="RWOT's Skotos Git URL" default="https://github.com/noahgibbs/vRWOT_SkotOS" example="SkotOS Git URL to clone for your game." optional="false" />
# RWOT_SKOTOS_GIT_URL=
# <UDF name="rwot_skotos_git_branch" label="RWOT's Skotos Git Branch" default="rwot_prototype" example="SkotOS branch, tag or commit to clone for your game." optional="false" />
# RWOT_SKOTOS_GIT_BRANCH=

set -e
set -x

# e.g. clone_or_update "$SKOTOS_GIT_URL" "$SKOTOS_GIT_BRANCH" "/var/skotos"
function clone_or_update {
  if [ -d "$3" ]
  then
    pushd "$3"
    git checkout "$2"
    git pull
    popd
  else
    git clone "$1" "$3"
    pushd "$3"
    git checkout "$2"
    popd
  fi
  chgrp -R skotos "$3"
  chown -R skotos "$3"
  chmod -R g+w "$3"
}

export HOSTNAME="rwot"
export FQDN_CLIENT=rwot."$SUBDOMAIN"
export FQDN_LOGIN=rwot-login."$SUBDOMAIN"
export SKOTOS_GIT_URL="$RWOT_SKOTOS_GIT_URL"
export SKOTOS_GIT_BRANCH="$RWOT_SKOTOS_GIT_BRANCH"
export ORCHIL_GIT_URL=https://github.com/noahgibbs/vRWOT_Orchil
export ORCHIL_GIT_BRANCH=master
export DGD_GIT_URL=https://github.com/ChatTheatre/dgd
export DGD_GIT_BRANCH=master
export THINAUTH_GIT_URL=https://github.com/ChatTheatre/thin-auth
export THINAUTH_GIT_BRANCH=master

# First, set up the node using the normal SkotOS Linode stackscript
clone_or_update "$RWOT_SKOTOS_GIT_URL" "$RWOT_SKOTOS_GIT_BRANCH" /var/rwot_skotos
cp /var/rwot_skotos/dev_scripts/stackscript/linode_stackscript.sh ~root/
. ~root/linode_stackscript.sh
