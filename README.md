# PowerCLI
Repository for all things PowerCLI

---

## Power-Tools

In serial for a .csv list of VMs, the script will do any of the following:
 * audit Hot-Add, Snapshots, Time Sync, Configured and Running OS Version
 * create Snapshots, remove Snapshots, and/or Enable Time Sync 
 * enable hot-add cpu and memory**
 * update Memory in GBs**
 * update CPU Cores**
 * configure OS Version**
 * execute rolling reboots**
 * execute shutdown**
 * execute startup

### Notes/Warnings:
 * Audit reports will be created in a new sub directory located with the .csv list of VMs.
 * For rolling reboots a time delay is required in seconds starting after the current nodes begins responding to RDP or SSH requests before it moves to the next node in the list.
 * Actions above that contain ** will shutdown the VM.
 * Ensure that all manual startup tasks are executed upon reboot, appropriate suppressions are requested, and that VM tools is installed and functioning on the node.
 * .csv file should have two columns labeled "VM" and "vCenter"; if updating memory, CPUs, or OS Version the file should also contain columns labeled "CPU", "MEM", or "OS".
 * Script will check github for latest version available and prompt for action. 

### OS Versions Syntax
 * oracleLinux64Guest="Oracle Linux 5/6 and above 64bit"
 * oracleLinux7_64Guest="Oracle Linux 7 64bit"
 * rhel6_64Guest="Red Hat 6 64bit"
 * windows9Server64Guest="Windows Server 2016 64bit"
 * windows8Server64Guest="Windows Server 2012 64bit"
 

---

## Contributors
[**Jared Brogan**](https://github.com/jaredbrogan)
