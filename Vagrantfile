# -*- mode: ruby -*-
# vi: ft=ruby:et:ts=2:sts=2:sw=2

VAGRANTFILE_API_VERSION = 2


require 'yaml'

#
# Defaults for Configuration data.
# Will be overridden from the settings file
# and (possibly later) from commandline parameters.
#

net_default = {
  :type   => 'veth',
  :flags  => 'up',
  :hwaddr => '',
  :name   => '',
  :ipv4   => '',
  :ipv6   => '',
}

network_opts = [ :type, :link, :flags, :hwaddr, :name, :ipv4, :ipv6 ]

libvirt_network_parms = {
  :hwaddr => :mac,
  :ipv4   => :ip,
  :ipv6   => '',
  :link   => '',
  :flags  => '',
  :type   => '',
}

defaults = {
  :provider => {
    :libvirt => {
      :prefix => 'vagrant',
    },
  },
}


vms = [
  {
    #:hostname => 'gluno1',
    :hostname => 'node1',
    #:box => 'local-fedora-rawhide-64',
    #:box => 'purpleidea-fedora-21',
    #:box => 'local-fedora-21.2',
    :provider => {
      :lxc => {
        :container_name => 'gluno1',
        #:container_name => 'node1',
      },
      :libvirt => {
        :box => 'local-fedora-21.2',
        :prefix => 'gluster',
      }, 
    },
    :internal_if => 'virbr1',
    :networks => [
      {
        :link => 'virbr1',
        :ipv4 => '172.20.10.30',
      },
      #{
      #  :link => 'virbr2',
      #  #:ipv4 => '10.111.222.201',
      #},
    ],
  },
]

#
# Load the config, if it exists,
# possibly override with commandline args,
# (currently none supported yet)
# and then store the config.
#

projectdir = File.expand_path File.dirname(__FILE__)
f = File.join(projectdir, 'vagrant.yaml')
if File.exists?(f)
  settings = YAML::load_file f

  if settings[:vms].is_a?(Array)
    vms = settings[:vms]
  end
  puts "Loaded settings from #{f}."
end

# TODO(?): ARGV-processing

settings = {
  :vms  => vms,
}

File.open(f, 'w') do |file|
  file.write settings.to_yaml
end
puts "Wrote settings to #{f}."


# apply defaults:

vms.each do |vm|
  defaults.keys.each do |cat|
    next if not vm.has_key?(cat)
    defaults[cat].keys.each do |subcat|
      next if not vm[cat].has_key?(subcat)
      defaults[cat][subcat].keys.each do |key|
        if not vm[cat][subcat].has_key?(key)
          vm[cat][subcat][key] = defaults[cat][subcat][key]
        end
      end
    end
  end

  #if not vm[:provider][:libvirt].has_key?(:prefix)
  #  vm[:provider][:libvirt][:prefix] = default_libvirt_prefix
  #end

  vm[:networks].each do |net|
    net_default.keys.each do |key|
      if not net.has_key?(key)
        net[key] = net_default[key]
      end
    end
  end
end


# compose the list of cluster internal ips
#
cluster_internal_ips = vms.map do |vm|
  net = nil
  vm[:networks].each do |n|
    if n[:link] == vm[:internal_if]
      net = n
      break
    end
  end
  if net != nil
    net[:ipv4]
  end
end

#print "internal ips: "
#print cluster_internal_ips
#print "\n"

#PROVISION_SCRIPT = <<SCRIPT
#yum -y install make samba
#SCRIPT

NET_FIX_ALWAYS_SCRIPT = <<SCRIPT
set -e
# eth1 is not brought up automatically
# by 'vagrant up' of the existing vm
# because eth1 is not up, glusterd can
# not be started and gluster volumes can
# not be mountd. fix it all up here until
# we have a correctly working environment
ifup eth1
MOUNTPT=/gluster/gv0
grep -q -s "${MOUNTPT}" /etc/fstab && {
  # already provisioned...
  systemctl restart glusterd
  mount ${MOUNTPT}
}
true
SCRIPT

NET_FIX_INITIAL_SCRIPT = <<SCRIPT
set -e
# Fix dhclient running on private network IF
ifdown eth1
systemctl restart NetworkManager
ifup eth1
SCRIPT

INSTALL_SCRIPT = <<SCRIPT
set -e
yum -y install xfsprogs
yum -y install glusterfs{,-server,-fuse,-geo-replication}
yum -y install ctdb samba
SCRIPT

XFS_SCRIPT = <<SCRIPT
set -e

DEVICE=$1
PARTDEV=${DEVICE}1
DISKDEV="/dev/${DEVICE}"
DISKPARTDEV="/dev/${PARTDEV}"
##MOUNTP=$2
MOUNTP=/export/${PARTDEV}
BRICKD=${MOUNTP}/brick

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

parted -s ${DISKDEV} print || {
  parted -s ${DISKDEV} mklabel msdos
}

parted -s ${DISKDEV} print 1 || {
  parted -s ${DISKDEV} mkpart primary 1 100%
}

blkid -s type ${DISKPARTDEV} | grep -q -s TYPE="xfs" || {
  mkfs.xfs -f ${DISKPARTDEV}
}

mkdir -p ${MOUNTP}

FILE=/etc/fstab

grep -q -s ${DISKPARTDEV} ${FILE} || {
  test -f ${FILE} || touch ${FILE}
  cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}
  cat <<EOF >> ${FILE}
${DISKPARTDEV} ${MOUNTP} xfs defaults 0 0
EOF
}

mount | grep ${MOUNTP} || {
  mount ${MOUNTP}
}

mkdir -p ${BRICKD}
SCRIPT

GLUSTER_START_SCRIPT = <<SCRIPT
set -e
systemctl start glusterd.service
SCRIPT

#GLUSTER_PROBE_SCRIPT = <<SCRIPT
#set -e
#
#PEER_IP=$1
#
#gluster peer probe ${PEER_IP}
#SCRIPT

GLUSTER_PROBE_SCRIPT = <<SCRIPT
set -e

PEER_IPS="$@"

for PEER_IP in ${PEER_IPS}
do
  # try for some time to reach the other node:
  for COUNT in $(seq 1 12)
  do
    gluster peer probe ${PEER_IP} && break
    sleep 1
  done
done
SCRIPT

GLUSTER_CREATEVOL_SCRIPT = <<SCRIPT
set -e
VOLNAME=$1
shift
REP=$1
shift

echo "gluster volume create $VOLNAME rep $REP transport tcp $@"
gluster volume create $VOLNAME rep $REP transport tcp $@

gluster volume start $VOLNAME
SCRIPT

GLUSTER_MOUNT_SCRIPT = <<SCRIPT
set -e
VOLNAME=$1
shift
MOUNTPT=$1
shift

MOUNTDEV="127.0.0.1:/${VOLNAME}"

mkdir -p ${MOUNTPT}

#mount -t glusterfs ${MOUNTDEV} ${MOUNTPT}

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

FILE=/etc/fstab

grep -q -s "${MOUNTPT}" ${FILE} || {
  test -f ${FILE} || touch ${FILE}
  cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

  cat <<EOF >> ${FILE}
${MOUNTDEV} ${MOUNTPT} glusterfs defaults,selinux 0 0
EOF
}

mount ${MOUNTPT}

SCRIPT


CTDB_STOP_SCRIPT = <<SCRIPT
set -e
systemctl stop ctdb.service
SCRIPT

CTDB_CREATE_NODES_SCRIPT = <<SCRIPT
set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

NODES_IPS="$@"

FILE=/etc/ctdb/nodes
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
for IP in ${NODES_IPS}
do
  echo "$IP" >> ${FILE}
done
SCRIPT

CTDB_CREATE_PUBADDRS_SCRIPT = <<SCRIPT
set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

PUB_IPS="$@"

FILE=/etc/ctdb/public_addresses
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
for IP in ${PUB_IPS}
do
  echo ${IP} >> ${FILE}
done
SCRIPT

CTDB_CREATE_CONF_SCRIPT = <<SCRIPT
set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

RECLOCKDIR=/gluster/gv0/ctdb
mkdir -p ${RECLOCKDIR}
RECLOCKFILE=${RECLOCKDIR}/reclock

PUBLIC_ADDRESSES_FILE=/etc/ctdb/public_addresses
NODES_FILE=/etc/ctdb/nodes

FILE=/etc/sysconfig/ctdb
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
cat <<EOF >> ${FILE}
CTDB_NODES=${NODES_FILE}
CTDB_PUBLIC_ADDRESSES=${PUBLIC_ADDRESSES_FILE}
CTDB_RECOVERY_LOCK=${RECLOCKFILE}
CTDB_MANAGES_SAMBA="yes"
CTDB_SAMBA_SKIP_SHARE_CKECK="yes"
#CTDB_MANAGES_WINBIND="yes"
EOF
SCRIPT

SAMBA_CREATE_CONF_SCRIPT = <<SCRIPT
set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

GLUSTER_VOL=$1

GLUSTER_VOL_MOUNT=$2

mkdir -p ${GLUSTER_VOL_MOUNT}/share1
chmod -R 0777 ${GLUSTER_VOL_MOUNT}/share1

mkdir -p ${GLUSTER_VOL_MOUNT}/share2
chmod -R 0777 ${GLUSTER_VOL_MOUNT}/share2

FILE=/etc/samba/smb.conf
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
cat <<EOF >> ${FILE}
[global]
    netbios name = sambacluster
    workgroup = vagrant
    security = user

    clustering = yes
    #include = registry

[share1]
    path = /share1
    vfs objects = acl_xattr glusterfs
    glusterfs:volume = ${GLUSTER_VOL}
    kernel share modes = no
    read only = no

[share2]
    path = ${GLUSTER_VOL_MOUNT}/share2
    vfs objects = acl_xattr
    read only = no
EOF
SCRIPT

CTDB_START_SCRIPT = <<SCRIPT
set -e
systemctl start ctdb.service
SCRIPT
#
# The vagrant machine definitions
#

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  vms.each do |machine|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:provider][:libvirt][:box]
      node.vm.hostname = machine[:hostname]

      node.vm.provider :libvirt do |libvirt|
        libvirt.default_prefix = machine[:provider][:libvirt][:prefix]
        libvirt.memory = 1024
        libvirt.storage :file, :size => '64M', :device => 'vdb'
        libvirt.storage :file, :size => '10G', :device => 'vdc'

        machine[:networks].each do |net|
          if not net[:ipv4] == ''
            node.vm.network :private_network, :ip => net[:ipv4]
          end
        end
      end


      # There is some problem with the fedora base box:
      # Upon first boot, ifdown eth1 fails and the dhclient
      # keep being active. Simply bringing down and up again
      # the interface is not sufficient. We need to restart
      # NetworkManager in order to teach it to not feel
      # responsible for the interface any more.
      node.vm.provision "net_fix_initial", type: "shell" do |s|
        s.inline = NET_FIX_INITIAL_SCRIPT
      end

      node.vm.provision "install", type: "shell" do |s|
        s.inline = INSTALL_SCRIPT
      end

      # There is some problem with the fedora base box:
      # We need to up the interface on reboots.
      # It does not come up automatically.
      node.vm.provision "net_fix_always", type: "shell", run: "always" do |s|
        s.inline = NET_FIX_ALWAYS_SCRIPT
      end

      # multiple privisioners with same name possible?
      node.vm.provision "xfs", type: "shell" do |s|
        s.inline = XFS_SCRIPT
        #s.args = [ "vdb", "/export/gluster/brick1" ]
        s.args = [ "vdb" ]
      end

      node.vm.provision "xfs", type: "shell" do |s|
        s.inline = XFS_SCRIPT
        #s.args = [ "vdc" , "/export/gluster/brick2" ]
        s.args = [ "vdc" ]
      end

      node.vm.provision "gluster_start", type: "shell" do |s|
        s.inline = GLUSTER_START_SCRIPT
      end

      node.vm.provision "gluster_probe", type: "shell" do |s|
        s.inline = GLUSTER_PROBE_SCRIPT
        s.args = cluster_internal_ips
      end

      node.vm.provision "gluster_createvol", type: "shell" do |s|
        mount_points = cluster_internal_ips.map do |ip|
          "#{ip}:/export/vdb1/brick"
        end
        s.inline = GLUSTER_CREATEVOL_SCRIPT
        s.args = [ "gv0", "3" ] + mount_points
      end

      node.vm.provision "gluster_mount", type: "shell" do |s|
        s.inline = GLUSTER_MOUNT_SCRIPT
        s.args = [ "gv0", "/gluster/gv0" ]
      end

      node.vm.provision "gluster_createvol", type: "shell" do |s|
        mount_points = cluster_internal_ips.map do |ip|
          "#{ip}:/export/vdc1/brick"
        end
        s.inline = GLUSTER_CREATEVOL_SCRIPT
        s.args = [ "gv1", "3" ] + mount_points
      end

      node.vm.provision "gluster_mount", type: "shell" do |s|
        s.inline = GLUSTER_MOUNT_SCRIPT
        s.args = [ "gv1", "/gluster/gv1" ]
      end

      #
      # ctdb / samba config
      #

      node.vm.provision "ctdb_stop", type: "shell" do |s|
        s.inline = CTDB_STOP_SCRIPT
      end

      node.vm.provision "ctdb_create_nodes", type: "shell" do |s|
        s.inline = CTDB_CREATE_NODES_SCRIPT
        s.args = cluster_internal_ips
      end

      #node.vm.provision "ctdb_create_pubaddrs", type: "shell" do |s|
      #  s.inline = CTDB_CREATE_PUBADDRS_SCRIPT
      #  s.arg =
      #end

      node.vm.provision "ctdb_create_conf", type: "shell" do |s|
        s.inline = CTDB_CREATE_CONF_SCRIPT
      end

      node.vm.provision "samba_create_conf", type: "shell" do |s|
        s.inline = SAMBA_CREATE_CONF_SCRIPT
        s.args = [ "gv1", "/gluster/gv1" ]
      end

      node.vm.provision "ctdb_start", type: "shell" do |s|
        s.inline = CTDB_START_SCRIPT
      end

    end
  end

end
