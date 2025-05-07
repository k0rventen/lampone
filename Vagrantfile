Vagrant.configure("2") do |config|
    # Define a common base configuration for all VMs
    config.vm.box = "debian/bookworm64"
    config.vm.provider "virtualbox" do |vb|
        vb.memory = "4096"
        vb.cpus = 4
    end
    # Define the master node
    config.vm.define "staging-master" do |master|
      master.vm.hostname = "k3s-master"
      master.vm.network "private_network", ip: "192.168.56.10"
      master.vm.network "forwarded_port", guest: 6443, host: 6443
    end
    # And a worker
    config.vm.define "staging-worker" do |master|
      master.vm.hostname = "k3s-worker"
      master.vm.network "private_network", ip: "192.168.56.11"
    end
  end
