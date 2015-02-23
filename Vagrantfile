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


#PROVISION_SCRIPT = <<SCRIPT
#yum -y install make samba
#SCRIPT

NET_FIX_ALWAYS_SCRIPT = <<SCRIPT
set -e
# eth1 is not brought up automatically
# by 'vagrant up' of the existing vm
ifup eth1
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

parted -s ${DISKDEV} mklabel msdos
parted -s ${DISKDEV} mkpart primary 1 100%
mkfs.xfs -f ${DISKPARTDEV}

mkdir -p ${MOUNTP}

FILE=/etc/fstab
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

cat <<EOF >> ${FILE}
${DISKPARTDEV} ${MOUNTP} xfs defaults 0 0
EOF

mount ${MOUNTP}

mkdir ${BRICKD}
SCRIPT

GLUSTER_START_SCRIPT = <<SCRIPT
set -e
systemctl start glusterd.service
SCRIPT

GLUSTER_PROBE_SCRIPT = <<SCRIPT
set -e

PEER_IP=$1

gluster peer probe ${PEER_IP}
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
      # We need to up the interface on reboots.
      # It does not come up automatically.
      node.vm.provision :shell, run: "always" do |s|
        s.inline = NET_FIX_ALWAYS_SCRIPT
      end

      # There is some problem with the fedora base box:
      # Upon first boot, ifdown eth1 fails and the dhclient
      # keep being active. Simply bringing down and up again
      # the interface is not sufficient. We need to restart
      # NetworkManager in order to teach it to not feel
      # responsible for the interface any more.
      node.vm.provision :shell do |s|
        s.inline = NET_FIX_INITIAL_SCRIPT
      end

      node.vm.provision :shell do |s|
        s.inline = INSTALL_SCRIPT
      end

      node.vm.provision :shell do |s|
        s.inline = XFS_SCRIPT
        #s.args = [ "vdb", "/export/gluster/brick1" ]
        s.args = [ "vdb" ]
      end

      node.vm.provision :shell do |s|
        s.inline = XFS_SCRIPT
        #s.args = [ "vdc" , "/export/gluster/brick2" ]
        s.args = [ "vdc" ]
      end

      node.vm.provision :shell do |s|
        s.inline = GLUSTER_START_SCRIPT
      end

    end
  end

end
