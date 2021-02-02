#!/bin/bash

# <UDF name="subdomain" label="Subdomain to contain rwot and rwot-login" example="Example: game.my-domain.com"/>
# SUBDOMAIN=
# <UDF name="userpassword" label="Deployment User Password" example="Password for various accounts and infrastructure." />
# USERPASSWORD=
# <UDF name="rwot_git_url" label="RWOT's Git URL" default="https://github.com/noahgibbs/prototype_vRWOT" example="RWOT Git URL to clone for your game." optional="false" />
# RWOT_GIT_URL=
# <UDF name="rwot_git_branch" label="RWOT's Git Branch" default="master" example="RWOT branch, tag or commit to clone for your game." optional="false" />
# RWOT_GIT_BRANCH=
# <UDF name="rwot_skotos_stackscript_url" label="URL for the base stackscript to build on" default="https://raw.githubusercontent.com/noahgibbs/vRWOT_SkotOS/master/dev_scripts/stackscript/linode_stackscript.sh" example="SkotOS stackscript to build on top of." optional="false" />
# RWOT_SKOTOS_STACKSCRIPT_URL=

set -e
set -x

# Output stdout and stderr to ~root files
exec > >(tee -a /root/standup.log) 2> >(tee -a /root/standup.log /root/standup.err >&2)

# e.g. clone_or_update "$SKOTOS_GIT_URL" "$SKOTOS_GIT_BRANCH" "/var/skotos"
function clone_or_update {
  if [ -d "$3" ]
  then
    pushd "$3"
    git fetch # Needed for "git checkout" if the branch has been added recently
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

# Parameters to pass to the SkotOS stackscript
export HOSTNAME="rwot"
export FQDN_CLIENT=rwot."$SUBDOMAIN"
export FQDN_LOGIN=rwot-login."$SUBDOMAIN"
export SKOTOS_GIT_URL=https://github.com/noahgibbs/vRWOT_SkotOS
export SKOTOS_GIT_BRANCH=rwot_prototype
export ORCHIL_GIT_URL=https://github.com/ChatTheatre/Orchil
export ORCHIL_GIT_BRANCH=master
export DGD_GIT_URL=https://github.com/ChatTheatre/dgd
export DGD_GIT_BRANCH=master
export THINAUTH_GIT_URL=https://github.com/ChatTheatre/thin-auth
export THINAUTH_GIT_BRANCH=master

clone_or_update "$RWOT_GIT_URL" "$RWOT_GIT_BRANCH" /var/rwot

if [ -z "$SKIP_INNER" ]
then
    # Set up the node using the normal SkotOS Linode stackscript
    curl $RWOT_SKOTOS_STACKSCRIPT_URL > ~root/linode_stackscript.sh
    . ~root/linode_stackscript.sh
fi

export FQDN_MEET=meet."$SUBDOMAIN"

ufw allow 10000/udp # For Jitsi Meet server
ufw allow 3478/udp # For STUN server
ufw allow 5349/tcp # For fallback video/audio with coturn

certbot --non-interactive --apache --agree-tos -m webmaster@$FQDN_CLIENT -d $FQDN_CLIENT -d $FQDN_LOGIN -d $FQDN_MEET

# If we're still running then everything was set up correctly.

apt install gnupg2 apt-transport-https -y

# Needed for Jitsi on Ubuntu - not Debian? (https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart)
#apt-add-repository universe

# Install OpenJDK 8 for Jitsi (https://adoptopenjdk.net/installation.html#linux-pkg)
wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add -
echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb buster main" | sudo tee /etc/apt/sources.list.d/adoptopenjdk.list

# Add Jitsi package repository (https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart)
curl https://download.jitsi.org/jitsi-key.gpg.key | sudo sh -c 'gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg'
echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list > /dev/null

apt update
apt install adoptopenjdk-8-hotspot -y

# dgd-tools contains dgd-manifest
gem install dgd-tools bundler

# Keep SkotOS DGD from being restarted by cron.
touch /var/skotos/no_restart.txt
# We'll shut down SkotOS's DGD server and set up our own RWOT-specific DGD app.
/var/skotos/dev_scripts/stackscript/stop_dgd_server.sh

# Reset the logfile
rm -f /var/log/dgd_server.out
touch /var/log/dgd_server.out
chown skotos /var/log/dgd_server.out

# Add entry to ~skotos/crontab.txt for RWOT SkotOS
cat >>~skotos/crontab.txt <<EndOfMessage
* * * * *  /var/rwot/start_rwot_server.sh
EndOfMessage

cat >~skotos/dgd_setup.sh <<EndOfMessage
#!/bin/bash

set -e
set -x

cd /var/rwot
bundle install
bundle exec dgd-manifest install

crontab ~/crontab.txt
EndOfMessage
chmod +x ~skotos/dgd_setup.sh
sudo -u skotos ~skotos/dgd_setup.sh

touch ~/rwot_stackscript_finished_successfully.txt

# TODO: apt install jitsi-meet   # Will probably have questions and config...
