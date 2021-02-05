# Prototype for vRWOT

This is the initial prototype code for vRWOT, based on SkotOS.

## Creating a Linode VM

The Linode Stackscript can be found in rwot_stackscript.sh. You can paste it into a StackScript on Linode and create an instance from it.

You'll need to create three DNS entries immediately, right after you hit "create" on the Linode. They should be called rwot, rwot-login and meet on the subdomain you gave as a parameter to the script. For instance, I use madrubyscience.com, so my three hostnames would be rwot.madrubyscience.com, rwot-login.madrubyscience.com and meet.madrubyscience.com.

Your instance should be at least 2GB in size. Anything smaller can't support MariaDB, it dies from lack of memory.

## Updating the Stackscript

The Stackscript tries to be re-runnable where possible. So in many cases if you're changing it you can just re-run it with the appropriate environment variables set.

In some cases you may need to create a new Linode VM or reset an old one to a previous state and re-run.

The existing DNS entries will normally work fine unless you create a new Linode.

## TODO Items

* Change Jekyll \_config.yml for final location - not under "noahgibbs"

# Linode Debugging Docs

A lot of these should move into SkotOS-Doc when we move the appropriate SkotOS changes over.

## Problems with Accounts and Authentication

Having trouble with authentication on a production (thin-auth) setup? One thing to try is the dev_scripts/stackscript/show_all_log.sh script. It will run "tail -f" to show all changes to a lot of different authentication-related and DGD-related logfiles. Now try logging in. What do you see in the logs?

## Restarting DGD

Sometimes you'll want to change files and restart DGD. DGD doesn't make this easy for some file types - skotos.database caches built code and various data.

If you want to fully stop DGD, first go into /var/rwot (NOTE: /var/skotos on non-RWOT hosts) and touch no_restart.txt. Then run the stop script for the server (/var/rwot/stop_rwot_server.sh or /var/skotos/dev_scripts/stackscript/stop_dgd_server.sh). Remove the skotos.database file.

This fully stops DGD, and removes all cached code and information. Next time you restart the server (by removing no_restart.txt and either waiting or manually starting it) you'll get a slow boot that rebuilds everything. Nothing will be cached. That's important if you want to change WOE objects by modifying their XML files, or DGD source files (.c and .h files.)
