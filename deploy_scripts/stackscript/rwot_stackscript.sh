#!/bin/bash

# <UDF name="subdomain" label="Subdomain to contain rwot and rwot-login" example="Example: game.my-domain.com"/>
# SUBDOMAIN=
# <UDF name="userpassword" label="Deployment User Password" example="Password for various accounts and infrastructure." />
# USERPASSWORD=
# <UDF name="game_git_url" label="The Game's Git URL" default="https://github.com/WebOfTrustInfo/prototype_vRWOT" example="Game Git URL to clone for your game." optional="false" />
# GAME_GIT_URL=
# <UDF name="game_git_branch" label="The Game's Git Branch" default="master" example="Game branch, tag or commit to clone for your game." optional="false" />
# GAME_GIT_BRANCH=
# <UDF name="skotos_stackscript_url" label="URL for the base stackscript to build on" default="https://raw.githubusercontent.com/ChatTheatre/SkotOS/master/deploy_scripts/stackscript/linode_stackscript.sh" example="SkotOS stackscript to build on top of." optional="false" />
# SKOTOS_STACKSCRIPT_URL=

set -e
set -x

# Output stdout and stderr to ~root files
exec > >(tee -a /root/game_standup.log) 2> >(tee -a /root/game_standup.log /root/game_standup.err >&2)

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
export FQDN_JITSI=meet."$SUBDOMAIN"
export SKOTOS_GIT_URL=https://github.com/ChatTheatre/SkotOS
export SKOTOS_GIT_BRANCH=master
export DGD_GIT_URL=https://github.com/ChatTheatre/dgd
export DGD_GIT_BRANCH=master
export THINAUTH_GIT_URL=https://github.com/ChatTheatre/thin-auth
export THINAUTH_GIT_BRANCH=master
export TUNNEL_GIT_URL=https://github.com/ChatTheatre/websocket-to-tcp-tunnel
export TUNNEL_GIT_BRANCH=master

if [ -z "$SKIP_INNER" ]
then
    echo "Running SkotOS StackScript..."
    # Set up the node using the normal SkotOS Linode stackscript
    curl $SKOTOS_STACKSCRIPT_URL > ~root/skotos_stackscript.sh
    . ~root/skotos_stackscript.sh
fi

clone_or_update "$GAME_GIT_URL" "$GAME_GIT_BRANCH" /var/game

# Reset the logfile
rm -f /var/log/dgd/server.out

touch /var/log/start_game_server.sh
chown skotos /var/log/start_game_server.sh

# Replace Crontab with just the pieces we need - specifically, do NOT start the old SkotOS DGD server any more.
if grep /var/game/deploy_scripts/stackscript/start_game_server.sh ~skotos/crontab.txt
then
  echo "Crontab has the appropriate entry already..."
else
  cat >>~skotos/crontab.txt <<EndOfMessage
* * * * *  /var/game/deploy_scripts/stackscript/start_game_server.sh >>/var/log/start_game_server.sh
EndOfMessage
fi

# In case we're re-running, don't keep statedump files around and keep DGD server from restarting until we're ready.
touch /var/game/no_restart.txt
/var/game/deploy_scripts/stackscript/stop_game_server.sh
rm -f /var/game/skotos.database*

cd /var/game && bundle install

cat >~skotos/dgd_pre_setup.sh <<EndOfMessage
#!/bin/bash

set -e
set -x

cd /var/game
bundle exec dgd-manifest install
EndOfMessage
chmod +x ~skotos/dgd_pre_setup.sh
sudo -u skotos -g skotos ~skotos/dgd_pre_setup.sh

# We modify files in /var/game/.root after dgd-manifest has created the initial app directory.
# But we also copy those files into /var/game/root (note: no dot) so that if the user later
# rebuilds with dgd-manifest, the modified files will be kept.

# Fix the login URL
HTTP_FILE=/var/game/.root/usr/HTTP/sys/httpd.c
if grep -F "www.skotos.net/user/login.php" $HTTP_FILE
then
    # Unpatched - need to patch
    sed -i "s_https://www.skotos.net/user/login.php_http://${FQDN_LOGIN}_" $HTTP_FILE
else
    echo "HTTPD appears to be patched already. Moving on..."
fi
sudo -u skotos -g skotos mkdir -p /var/game/usr/HTTP/sys
sudo -u skotos -g skotos cp $HTTP_FILE /var/game/usr/HTTP/sys/

# Instance file
sudo -u skotos -g skotos cat >/var/game/.root/usr/System/data/instance <<EndOfMessage
portbase 10000
hostname $FQDN_CLIENT
bootmods DevSys Theatre Jonkichi Tool Generic SMTP Gables
textport 443
real_textport 10443
webport 10803
real_webport 10080
url_protocol https
access gables
memory_high 128
memory_max 256
statedump_offset 600
freemote +emote
EndOfMessage
sudo -u skotos -g skotos mkdir -p /var/game/root/usr/System/data/
sudo -u skotos -g skotos cp /var/game/.root/usr/System/data/instance /var/game/root/usr/System/data/

sudo -u skotos -g skotos cat >/var/game/root/usr/Gables/data/www/profiles.js <<EndOfMessage
"use strict";
// orchil/profiles.js
var profiles = {
        "portal_gables":{
                "method":   "websocket",
                "protocol": "wss",
                "web_protocol": "https",
                "server":   "$FQDN_CLIENT",
                "port":      10810,
                "woe_port":  10812,
                "http_port": 10803,
                "path":     "/gables",
                "extra":    "",
                "reports":   false,
                "chars":    true,
        }
};
EndOfMessage
sudo -u skotos -g skotos cp /var/game/root/usr/Gables/data/www/profiles.js /var/game/.root/usr/Gables/data/www/

sudo -u skotos -g skotos cat >~skotos/dgd_final_setup.sh <<EndOfMessage
crontab ~/crontab.txt
rm -f /var/game/no_restart.txt  # Just in case
EndOfMessage
chmod +x ~skotos/dgd_final_setup.sh
sudo -u skotos -g skotos ~skotos/dgd_final_setup.sh
rm ~skotos/dgd_final_setup.sh

# Get set up for a fresh DGD restart from cron - let it happen again.
rm -f /var/game/skotos.database /var/game/skotos.database.old /var/game/no_restart.txt

touch ~/game_stackscript_finished_successfully.txt
