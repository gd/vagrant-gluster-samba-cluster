#!/bin/bash

# workaround the inability of parallel provisioning with virtualbox backend,
# as step zero, call vagrant up w/o provisioning!
#
# split the provisioning of virtualbox vms into three parts:
#
# one:    rollout everything just until the gluster_probe step
# probe:  just do the gluster_probe step on one node (node0)
# two:    rollout everything after the gluster_probe step

provision_zero()
{
	vagrant up --provider=virtualbox --no-provision
}

provision_one()
{
	vagrant provision --provision-with "selinux"
	vagrant provision --provision-with "install"
	vagrant provision --provision-with "create_brick_0,create_brick_1"
	vagrant provision --provision-with "gluster_start"
}

provision_probe()
{
	vagrant provision node0 --provision-with "gluster_probe"
}

provision_two()
{
	vagrant provision --provision-with "gluster_wait_peers"
	vagrant provision --provision-with "gluster_createvol_0,gluster_createvol_1"
	vagrant provision --provision-with "gluster_mount_0,gluster_mount_1"

	vagrant provision --provision-with "ctdb_stop,ctdb_create_nodes,ctdb_create_conf,samba_create_conf,ctdb_start"
}

case $1 in
zero)
	provision_zero
	;;
one)
	provision_one
	;;
probe)
	provision_probe
	;;
two)
	provision_two
	;;
all)
	provision_one
	provision_probe
	provision_two
	;;
*)
    echo "Usage: $0 {zero|one|probe|two}"
    exit 1
esac

