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
