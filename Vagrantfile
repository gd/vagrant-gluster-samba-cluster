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
      :box => 'fedora/23-cloud-base',
    },
    :virtualbox => {
      :prefix => 'vagrant',
      :box => 'fedora/23-cloud-base',
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


NET_FIX_ALWAYS_SCRIPT = <<SCRIPT
set -e

# eth1 is not brought up automatically
# by 'vagrant up' of the existing vm.
# because eth1 is not up, glusterd can
# not be started and gluster volumes can
# not be mounted. fix it all up here until
# we have a correctly working environment.
ifdown eth1
ifup eth1

MOUNTPTS="$@"

for MOUNTPT in $MOUNTPTS
do
  grep -q -s "${MOUNTPT}" /etc/fstab && {
    # already provisioned...
    systemctl start glusterd
    # sleep to give glusterd some time to start up
    sleep 2

    mount | grep -q -s "${MOUNTPT}" && {
      echo "${MOUNTPT} is already mounted."
    } || {
      echo "Mounting ${MOUNTPT}."
      mount ${MOUNTPT}
    }

    systemctl start ctdb
  } || {
    # not provisioned yet
    echo "${MOUNTPT} not set up yet. Not mounting."
  }
done

SCRIPT

NET_FIX_INITIAL_SCRIPT = <<SCRIPT
set -e
# Fix dhclient running on private network IF
ifdown eth1
systemctl restart NetworkManager
ifdown eth1
ifup eth1
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


#
# disks: hard-coded for all nodes for now:
# TODO: make (some of) these configurable ...
#
disks = [
      {
        :size => 1, # in GB
        #:volname => "gv0",
      },
      {
        :size => 10,
        #:volname => "gv1",
      },
]

driveletters = ('b'..'z').to_a

#brick_mount_prefix = "/export"
brick_mount_prefix = "/bricks"
brick_path_suffix = "brick"
gluster_volume_prefix = "gv"
gluster_mount_prefix = "/gluster"

disks.each_with_index do |disk,disk_num|
  disk[:number] = disk_num
  disk[:volume_name] = "#{gluster_volume_prefix}#{disk[:number]}"
  disk[:volume_mount_point] = "#{gluster_mount_prefix}/#{disk[:volume_name]}"
  disk[:dev_names] = {
    :libvirt => "vd#{driveletters[disk[:number]]}",
    :virtualbox => "sd#{driveletters[disk[:number]]}",
  }
  disk[:dev_name] = "sd#{driveletters[disk[:number]]}"
  disk[:brick_name] = "brick0"
  disk[:label] = "#{disk[:volume_name]}-#{disk[:brick_name]}"
  disk[:brick_mount_point] = "#{brick_mount_prefix}/#{disk[:label]}"
  disk[:brick_path] = "#{disk[:brick_mount_point]}/#{brick_path_suffix}"
end

# /dev/{sv}db --> xfs filesys (on /dev/{sv}db1)
#  --> mount unter /bricks/gv0
#    --> dir /bricks/gv0/brick --> dir for gluster createvol gv0
#      --> gluster/fuse mount /gluster/gv0


my_config = {
  :provider => :libvirt,
}

#
# The vagrant machine definitions
#

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.synced_folder ".", "/vagrant", disabled: true
  #config.vm.synced_folder './', '/vagrant', type: '9p', disabled: false, accessmode: "squash", owner: "vagrant"

  #if Vagrant.has_plugin?("vagrant-cachier")
  #  config.cache.scope = :machine
  #  #config.cache.scope = :box

  #  config.cache.synced_folder_opts = {
  #    type: :nfs,
  #    # The nolock option can be useful for an NFSv3 client that wants to avoid the
  #    # NLM sideband protocol. Without this option, apt-get might hang if it tries
  #    # to lock files needed for /var/cache/* operations. All of this can be avoided
  #    # by using NFSv4 everywhere. Please note that the tcp option is not the default.
  #    #mount_options: ['rw', 'vers=3', 'tcp', 'nolock']
  #  }
  #end

  #config.vm.provider :libvirt
  #config.vm.provider :virtualbox

  #config.vm.provider :libvirt do |lv, override|
  #  my_config[:provider] = :libvirt
  #  #print "setting lv provider\n"
  #end
  #
  #config.vm.provider :virtualbox do |lv, override|
  #  my_config[:provider] = :virtualbox
  #  #print "setting vb provider\n"
  #end
  
  # just let one node do the probing
  probing = false

  vms.each_with_index do |machine,machine_num|
    config.vm.define machine[:hostname] do |node|
      node.vm.box = machine[:provider][:libvirt][:box]
      node.vm.hostname = machine[:hostname]

      print "machine #{machine_num}: #{machine[:hostname]}\n"

      node.vm.provider :libvirt do |libvirt|
        libvirt.default_prefix = machine[:provider][:libvirt][:prefix]
        libvirt.memory = 1024
        #libvirt.storage :file, :size => '64M', :device => 'vdb'
        #libvirt.storage :file, :size => '10G', :device => 'vdc'
      end

      node.vm.provider :virtualbox do |vb|
        #vb.default_prefix = machine[:provider][:virtualbox][:prefix]
        vb.memory = 1024
      end

      disks.each do |disk|
        node.vm.provider :libvirt do |lv|
          #print " [libvirt] disk ##{disk[:number]}: #{disk[:dev_names][:libvirt]}\n"
          #lv.storage :file, :size => "#{disk[:size]}G", :device => "#{disk[:dev_names][:libvirt]}"
          print " [libvirt] attaching disk ##{disk[:number]}: #{disk[:dev_name]}\n"
          lv.storage :file, :size => "#{disk[:size]}G", :bus => "sata" , :device => "#{disk[:dev_name]}"
        end
        node.vm.provider :virtualbox do |vb|
          disk_size = disk[:size]*1024
          #disk_file = "disk-#{machine_num}-#{disk[:dev_names][:virtualbox]}.vdi"
          #print " [virtualbox] disk ##{disk[:number]}: #{disk[:dev_names][:virtualbox]}\n"
          disk_file = "disk-#{machine_num}-#{disk[:dev_name]}.vdi"
          print " [virtualbox] attaching disk ##{disk[:number]}: #{disk[:dev_name]}\n"
          vb.customize [ "createhd", "--filename", disk_file, "--size", disk_size ]
          vb.customize [ "storageattach", :id, "--storagectl", "SATA Controller", "--port", 3+disk[:number], "--device", 0, "--type", "hdd", "--medium", disk_file ]
        end
      end

      machine[:networks].each do |net|
        if not net[:ipv4] == ''
          node.vm.network :private_network, :ip => net[:ipv4]
        end
      end

      node.vm.provision "selinux", type: "shell" do |s|
        s.path = "provision/shell/sys/selinux-off.sh"
      end

      # There is some problem with the fedora base box:
      # Upon first boot, ifdown eth1 fails and the dhclient
      # keep being active. Simply bringing down and up again
      # the interface is not sufficient. We need to restart
      # NetworkManager in order to teach it to not feel
      # responsible for the interface any more.
      ###node.vm.provision "net_fix_initial", type: "shell" do |s|
      ###  s.inline = NET_FIX_INITIAL_SCRIPT
      ###end

      node.vm.provision "install", type: "shell" do |s|
        s.path = "provision/shell/sys/install-yum.sh"
        s.args = [ "xfsprogs",
                   "glusterfs",
                   "glusterfs-server",
                   "glusterfs-fuse",
                   "glusterfs-geo-replication",
                   "ctdb",
                   "samba",
                   "samba-client",
                   "samba-vfs-glusterfs" ]
      end

      # There is some problem with the fedora base box:
      # We need to up the interface on reboots.
      # It does not come up automatically.
      ###node.vm.provision "net_fix_always", type: "shell", run: "always" do |s|
      ###  s.inline = NET_FIX_ALWAYS_SCRIPT
      ###  s.args = [ '/gluster/gv0', '/gluster/gv1' ]
      ###end

      # multiple privisioners with same name possible?

      disks.each do |disk|

        #print " create_brick: /dev/#{disk[:dev_name]} under #{disk[:brick_mount_point]}\n"
        #node.vm.provision "create_brick_#{disk[:number]}", type: "shell" do |s|
        #  s.path = "provision/shell/gluster/create-brick.sh"
        #  s.args = [ disk[:dev_name], disk[:brick_mount_point], brick_path_suffix ]
        #end

        print " create_brick: size #{disk[:size]}G, label #{disk[:label]} under #{disk[:brick_mount_point]}\n"
        node.vm.provision "create_brick_#{disk[:number]}", type: "shell" do |s|
          s.path = "provision/shell/gluster/create-brick.v2.sh"
          s.args = [ "#{disk[:size]}G", disk[:label], disk[:brick_mount_point], brick_path_suffix ]
        end

        ### node.vm.provision "create_brick_#{disk[:number]}", type: "shell" do |s|
        ###   # empty dummy...
        ### end

        ### # would like to use the actual provider name ... :-(
        ### # https://github.com/mitchellh/vagrant/issues/1867
        ### #
        ### ##node.vm.provision "disk_#{disk[:number]}", type: "shell" do |s|
        ### ##  s.path = "provision/shell/gluster/create-brick.sh"
        ### ##  s.args = [ disk[:dev_names][my_config[:provider]], disk[:brick_mount_point], brick_path_suffix ]
        ### ##end
        ### node.vm.provider :libvirt do |lv,override|
        ###   print " create_brick: /dev/#{disk[:dev_names][:libvirt]} under #{disk[:brick_mount_point]}\n"
        ###   override.vm.provision "create_brick_#{disk[:number]}", type: "shell" do |s|
        ###     s.path = "provision/shell/gluster/create-brick.sh"
        ###     s.args = [ disk[:dev_names][:libvirt], disk[:brick_mount_point], brick_path_suffix ]
        ###   end
        ### end
        ### node.vm.provider :virtualbox do |vb,override|
        ###   print " create_brick: /dev/#{disk[:dev_names][:virtualbox]} under #{disk[:brick_mount_point]}\n"
        ###   override.vm.provision "create_brick_#{disk[:number]}", type: "shell" do |s|
        ###     s.path = "provision/shell/gluster/create-brick.sh"
        ###     s.args = [ disk[:dev_names][:virtualbox], disk[:brick_mount_point], brick_path_suffix ]
        ###   end
        ### end
      end
      

      node.vm.provision "gluster_start", type: "shell" do |s|
        s.path = "provision/shell/gluster/gluster-start.sh"
      end

      if !probing
        probing = true
        node.vm.provision "gluster_probe", type: "shell" do |s|
          s.path = "provision/shell/gluster/gluster-probe.sh"
          s.args = cluster_internal_ips
        end
      end

      node.vm.provision "gluster_wait_peers", type: "shell" do |s|
        s.path = "provision/shell/gluster/gluster-wait-peers.sh"
        s.args = [ cluster_internal_ips.length, 300 ]
      end


      disks.each do |disk|
        brick_mount_points = cluster_internal_ips.map do |ip|
          "#{ip}:#{disk[:brick_path]}"
        end
        
        print " brick directories: #{brick_mount_points}\n"

        node.vm.provision "gluster_createvol_#{disk[:number]}", type: "shell" do |s|
          s.path = "provision/shell/gluster/gluster-create-volume.sh"
          s.args = [ disk[:volume_name], "3" ] + brick_mount_points
        end

        node.vm.provision "gluster_mount_#{disk[:number]}", type: "shell" do |s|
          s.path = "provision/shell/gluster/gluster-mount-volume.sh"
          s.args = [ disk[:volume_name], disk[:volume_mount_point] ]
        end
      end

      #
      # ctdb / samba config
      #

      node.vm.provision "ctdb_stop", type: "shell" do |s|
        s.path = "provision/shell/ctdb/ctdb-stop.sh"
      end

      node.vm.provision "ctdb_create_nodes", type: "shell" do |s|
        s.path = "provision/shell/ctdb/ctdb-create-nodes.sh"
        s.args = cluster_internal_ips
      end

      #node.vm.provision "ctdb_create_pubaddrs", type: "shell" do |s|
      #  s.path = "provision/shell/ctdb/ctdb-create-pubaddrs.sh"
      #  s.arg =
      #end

      node.vm.provision "ctdb_create_conf", type: "shell" do |s|
        s.path = "provision/shell/ctdb/ctdb-create-conf.sh"
        s.args = [ "/gluster/gv0/ctdb" ]
      end

      node.vm.provision "samba_create_conf", type: "shell" do |s|
        s.inline = SAMBA_CREATE_CONF_SCRIPT
        s.args = [ "gv1", "/gluster/gv1" ]
      end

      node.vm.provision "ctdb_start", type: "shell" do |s|
        s.path = "provision/shell/ctdb/ctdb-start.sh"
      end

    end
  end

end
