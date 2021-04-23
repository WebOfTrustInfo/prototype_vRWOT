# Prototype for vRWOT

This is the initial prototype code for vRWOT, based on SkotOS.

It is highly, highly recommended that you read [the SkotOS documentation](https://ChatTheatre.github.io/SkotOS-Doc) for details on how to build a SkotOS game.

(NOTE: once the vRWOT fork of SkotOS-Doc is active, that link should probably change to https://WebOfTrustInfo.github.io/vRWOT-Doc and the same for setup links below.)

## Running Locally on a Mac

Run the script deploy_scripts/mac/setup.sh to install the necessary programs, clone SkotOS-related Git repos and generally get everything set up. Once you've successfully set everything up, you can instead run deploy_scripts/mac/start_server.sh for somewhat faster startup. Please note that YOUR FIRST STARTUP WILL BE QUITE SLOW as DGD compiles all its dynamic source into its in-memory representation. After that, it will dump its memory space to a file called skotos.database and will restart very quickly from that statedump.

The Mac setup script should open a Google Chrome window allowing you to click through to the game, or to the WOE editor called the Tree of WOE. It will also open a terminal window showing you the DGD logfile. Some transient errors as it boots up are fine. A serious error that stops it before it starts up isn't so good. A healthy (if slow) first boot will print periodic messages as it compiles, while the script patiently checks the network port to see if it's booted yet.

See https://ChatTheatre.github.io/SkotOS-Doc/setup.html for more details.

## Creating a Linode VM

The Linode Stackscript can be found in deploy_scripts/stackscript/rwot\_stackscript.sh. You can paste it into a StackScript on Linode and create an instance from it.

You'll need to create three DNS entries immediately, right after you hit "create" on the Linode. They should be called rwot, rwot-login and meet on the subdomain you gave as a parameter to the script. For instance if I use test-4.madrubyscience.com, so my three hostnames would be rwot.test-4.madrubyscience.com, rwot-login.test-4.madrubyscience.com and meet.test-4.madrubyscience.com.

Your instance should be at least 2GB in size. Anything smaller can't support MariaDB, it dies from lack of memory.

See https://ChatTheatre.github.io/SkotOS-Doc/setup_vps.html for troubleshooting tips and more details.
