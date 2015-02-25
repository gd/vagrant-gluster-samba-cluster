# Samba/CTDB/GlusterFS Cluster on libvirt/kvm

This repository contains a Vagrantfile that describes the
setup of a Samba-CTDB-GlusterFS-Cluster of fedora-libvirt/kvm
nodes.

In short:

* setup controlled by vagrant
* libvirt-vms as basis
* node OS: Fedora 21

## Configuration

This Vagrantfile is parametrized: The options for configuring
the number of nodes and the nodes' network interfaces and addresses
are stored in the config file 'vagrant.yml' when running any
vagrant command (except for vagrant help). The whole setup can
then conveniently be reconfigured modifying that file.

## Prerequisites

* Linux host, attached to the network (tested on Fedora 21, should work on other hosts as well)
* libvirt installed
* vagrant installed
* vagrant-libvirt plugin installed
* possibly preparation of bridge interfaces on the host

## Running

After adjusting the configuration, `vagrant up` will bring up the full
cluster with ctdb running on all nodes. `vagrant ssh node1` will ssh
into node1, etc.

## TODO

- provision ctdb public addresses

## Author

Michael Adam (obnox at samba dot org)
