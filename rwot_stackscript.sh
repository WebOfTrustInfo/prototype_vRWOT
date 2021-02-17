#!/bin/bash

# <UDF name="subdomain" label="Subdomain to contain rwot and rwot-login" example="Example: game.my-domain.com"/>
# SUBDOMAIN=
# <UDF name="userpassword" label="Deployment User Password" example="Password for various accounts and infrastructure." />
# USERPASSWORD=
# <UDF name="rwot_git_url" label="RWOT's Git URL" default="https://github.com/noahgibbs/prototype_vRWOT" example="RWOT Git URL to clone for your game." optional="false" />
# RWOT_GIT_URL=
# <UDF name="rwot_git_branch" label="RWOT's Git Branch" default="master" example="RWOT branch, tag or commit to clone for your game." optional="false" />
# RWOT_GIT_BRANCH=
# <UDF name="rwot_skotos_stackscript_url" label="URL for the base stackscript to build on" default="https://raw.githubusercontent.com/noahgibbs/vRWOT_SkotOS/rwot_prototype/dev_scripts/stackscript/linode_stackscript.sh" example="SkotOS stackscript to build on top of." optional="false" />
# RWOT_SKOTOS_STACKSCRIPT_URL=

set -e
set -x

# Output stdout and stderr to ~root files
exec > >(tee -a /root/rwot_standup.log) 2> >(tee -a /root/rwot_standup.log /root/rwot_standup.err >&2)

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
export TUNNEL_GIT_URL=https://github.com/noahgibbs/websocket-to-tcp-tunnel
export TUNNEL_GIT_BRANCH=script_improvements

if [ -z "$SKIP_INNER" ]
then
    # Set up the node using the normal SkotOS Linode stackscript
    curl $RWOT_SKOTOS_STACKSCRIPT_URL > ~root/linode_stackscript.sh
    . ~root/linode_stackscript.sh
fi

clone_or_update "$RWOT_GIT_URL" "$RWOT_GIT_BRANCH" /var/rwot

# If we're running on an already-provisioned system, don't keep DGD running
touch /var/rwot/no_restart.txt
/var/rwot/stop_rwot_server.sh

export FQDN_MEET=meet."$SUBDOMAIN"

ufw allow 10000/udp # For Jitsi Meet server
ufw allow 3478/udp # For STUN server
ufw allow 5349/tcp # For fallback video/audio with coturn

certbot certonly --non-interactive --nginx --agree-tos -m webmaster@$FQDN_CLIENT -d $FQDN_MEET

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

echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string $FQDN_MEET" | debconf-set-selections
echo "jitsi-meet jitsi-meet/cert-choice select Self-signed certificate will be generated" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
apt install jitsi-meet -y

# In case we're re-running
rm -f /etc/nginx/sites-enabled/${FQDN_MEET}.conf
ln -s /etc/nginx/sites-available/${FQDN_MEET}.conf /etc/nginx/sites-enabled/${FQDN_MEET}.conf

# Jitsi adds an NGinX site, which means we need to tell NGinX to load it.
nginx -t
nginx -s reload

# Switch Jitsi-meet to using Certbot certificates
echo "admin@$FQDN_CLIENT" | /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# dgd-tools contains dgd-manifest
gem install dgd-tools bundler

# Keep SkotOS DGD from being restarted by normal script (which shouldn't run anyway.)
touch /var/skotos/no_restart.txt
# We'll shut down SkotOS's DGD server and set up our own RWOT-specific DGD app.
/var/skotos/dev_scripts/stackscript/stop_dgd_server.sh

# Reset the logfile and DGD database
rm -f /var/log/dgd_server.out /var/log/dgd/server.out /var/skotos/skotos.database /var/skotos/skotos.database.old

touch /var/log/start_rwot_server.sh
chown skotos /var/log/start_rwot_server.sh

# Replace Crontab with just the pieces we need - specifically, do NOT start the old SkotOS DGD server any more.
cat >~skotos/crontab.txt <<EndOfMessage
@reboot /usr/local/websocket-to-tcp-tunnel/start-tunnel.sh
* * * * * /usr/local/websocket-to-tcp-tunnel/search-tunnel.sh
* * * * * /bin/bash -c "/var/www/html/user/admin/restartuserdb.sh >>/var/log/userdb/servers.txt"
* * * * * /var/skotos/dev_scripts/stackscript/keep_authctl_running.sh
1 5 1-2 * * /usr/bin/certbot renew
* * * * *  /var/rwot/start_rwot_server.sh >>/var/log/start_rwot_server.sh
EndOfMessage
chown skotos ~skotos/crontab.txt

# In case we're re-running, don't keep statedump files around
rm -f /var/rwot/skotos.database*

cat >~skotos/dgd_pre_setup.sh <<EndOfMessage
#!/bin/bash

set -e
set -x

cd /var/rwot
bundle install
bundle exec dgd-manifest install
EndOfMessage
chmod +x ~skotos/dgd_pre_setup.sh
sudo -u skotos ~skotos/dgd_pre_setup.sh

# We modify files in /var/rwot/.root after dgd-manifest has created the initial app directory.
# But we also copy those files into /var/rwot/root (note: no dot) so that if the user later
# rebuilds with dgd-manifest, the modified files will be kept.

# May need this for logging in on telnet port and/or admin-only emergency port
DEVUSERD=/var/rwot/.root/usr/System/sys/devuserd.c
if grep -F "user_to_hash = ([ ])" $DEVUSERD
then
    # Unpatched - need to patch
    sed -i "s/user_to_hash = (\[ \]);/user_to_hash = ([ \"admin\": to_hex(hash_md5(\"admin\" + \"$USERPASSWORD\")), \"skott\": to_hex(hash_md5(\"skott\" + \"$USERPASSWORD\")) ]);/g" $DEVUSERD
else
    echo "/var/rwot DevUserD appears to be patched already. Moving on..."
fi
mkdir -p /var/rwot/root/usr/System/sys
cp $DEVUSERD /var/rwot/root/usr/System/sys/
chown skotos:skotos /var/rwot/root/usr/System/sys/devuserd.c

# Fix the login URL
HTTP_FILE=/var/rwot/.root/usr/HTTP/sys/httpd.c
if grep -F "www.skotos.net/user/login.php" $HTTP_FILE
then
    # Unpatched - need to patch
    sed -i "s_https://www.skotos.net/user/login.php_http://${FQDN_LOGIN}_" $HTTP_FILE
else
    echo "HTTPD appears to be patched already. Moving on..."
fi
mkdir -p /var/rwot/usr/HTTP/sys
cp $HTTP_FILE /var/rwot/usr/HTTP/sys/
chown skotos:skotos /var/rwot/usr/HTTP/sys/httpd.c

# Instance file
cat >/var/rwot/.root/usr/System/data/instance <<EndOfMessage
portbase 10000
hostname $FQDN_CLIENT
bootmods DevSys Theatre Jonkichi Tool Generic SMTP UserDB Gables
textport 443
real_textport 10443
webport 10803
real_webport 10080
access gables
memory_high 128
memory_max 256
statedump_offset 600
freemote +emote
EndOfMessage
chown skotos:skotos /var/rwot/.root/usr/System/data/instance
cp /var/rwot/.root/usr/System/data/instance /var/rwot/root/usr/System/data/
chown skotos:skotos /var/rwot/root/usr/System/data/instance

sed -i "s_hostname=\"localhost\"_hostname=\"$FQDN_CLIENT\"_" /var/rwot/.root/data/vault/Theatre/Theatres/Tavern.xml
sed -i "s_hostname=\"localhost\"_hostname=\"$FQDN_CLIENT\"_" /var/rwot/root/data/vault/Theatre/Theatres/Tavern.xml

# Add vRWOT SkotOS config file
cat >/var/rwot/skotos.config <<EndOfMessage
telnet_port = ([ "*": 10098 ]); /* telnet port for low-level game admin access */
binary_port = ([ "*": 10099, /* admin-only emergency game access port */
             "*": 10017,     /* UserAPI::Broadcast port */
             "*": 10070,     /* UserDB Auth port - DO NOT EXPOSE THROUGH FIREWALL */
             "*": 10071,     /* UserDB Ctl port - DO NOT EXPOSE THROUGH FIREWALL */
             "*": 10080,     /* HTTP port */
             "*": 10089,     /* DevSys HTTP port */
             "*": 10090,     /* WOE port, relayed to by websockets */
             "*": 10091,     /* DevSys ExportD port */
             "*": 10443 ]);  /* TextIF port, relayed to by websockets */
directory   = "./.root";
users       = 100;
editors     = 0;
ed_tmpfile  = "../state/ed";
swap_file   = "../state/swap";
swap_size   = 1048576;      /* # sectors in swap file */
cache_size  = 8192;         /* # sectors in swap cache */
sector_size = 512;          /* swap sector size */
swap_fragment   = 4096;         /* fragment to swap out */
static_chunk    = 64512;        /* static memory chunk */
dynamic_chunk   = 261120;       /* dynamic memory chunk */
dump_interval   = 7200;         /* two hours between dumps */
dump_file   = "../skotos.database";

typechecking    = 2;            /* global typechecking */
include_file    = "/include/std.h"; /* standard include file */
include_dirs    = ({ "/include", "~/include" }); /* directories to search */
auto_object = "/kernel/lib/auto";   /* auto inherited object */
driver_object   = "/kernel/sys/driver"; /* driver object */
create      = "_F_create";      /* name of create function */

array_size  = 16384;        /* max array size */
objects     = 300000;       /* max # of objects */
call_outs   = 16384;        /* max # of call_outs */
EndOfMessage

cat >/var/www/html/client/profiles.js <<EndOfMessage
"use strict";
// orchil/profiles.js
var profiles = {
        "portal_gables":{
                "method":   "websocket",
                "protocol": "wss",
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
cp /var/www/html/client/profiles.js /var/rwot/root/usr/Gables/data/www/
chown skotos /var/rwot/root/usr/Gables/data/www/profiles.js
cp /var/www/html/client/profiles.js /var/rwot/.root/usr/Gables/data/www/
chown skotos /var/rwot/.root/usr/Gables/data/www/profiles.js

cat >~skotos/dgd_final_setup.sh <<EndOfMessage
crontab ~/crontab.txt
rm -f /var/rwot/no_restart.txt  # Just in case
EndOfMessage
chmod +x ~skotos/dgd_final_setup.sh
sudo -u skotos ~skotos/dgd_final_setup.sh

touch ~/rwot_stackscript_finished_successfully.txt
