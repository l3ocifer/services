# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'rbconfig'

def is_arm_mac?
  RUBY_PLATFORM.include?('arm64') && RbConfig::CONFIG['host_os'].include?('darwin')
end

def get_provider
  is_arm_mac? ? 'utm' : 'virtualbox'
end

Vagrant.configure("2") do |config|
  # Ubuntu (Linux) environment
  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = "ubuntu/focal64"
    ubuntu.vm.hostname = "ubuntu-test"
    ubuntu.vm.provider get_provider do |provider|
      provider.memory = "2048"
      provider.cpus = 2
      if provider.name == 'utm'
        provider.ssh_port = 22
      end
    end
    ubuntu.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3 python3-pip
      pip3 install ansible
    SHELL
    ubuntu.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "main.yml"
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3",
        is_linux: true
      }
    end
  end

  # WSL-like environment (Ubuntu based)
  config.vm.define "wsl" do |wsl|
    wsl.vm.box = "ubuntu/focal64"
    wsl.vm.hostname = "wsl-test"
    wsl.vm.provider get_provider do |provider|
      provider.memory = "2048"
      provider.cpus = 2
      if provider.name == 'utm'
        provider.ssh_port = 22
      end
    end
    wsl.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3 python3-pip
      pip3 install ansible
      # Simulate WSL environment
      echo 'WSL_DISTRO_NAME="Ubuntu-20.04"' >> /etc/environment
    SHELL
    wsl.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "main.yml"
      ansible.extra_vars = {
        ansible_python_interpreter: "/usr/bin/python3",
        is_wsl: true
      }
    end
  end

  # macOS environment (using VirtualBox or UTM)
  config.vm.define "macos" do |macos|
    if is_arm_mac?
      macos.vm.box = "yzgyyang/macOS-monterey-arm64"
      macos.vm.box_url = "https://utm.app/boxes/monterey-arm64.box"
    else
      macos.vm.box = "yzgyyang/macOS-monterey"
    end
    macos.vm.hostname = "macos-test"
    macos.vm.provider get_provider do |provider|
      if provider.name == 'virtualbox'
        provider.memory = "4096"
        provider.cpus = 2
        provider.customize ["modifyvm", :id, "--cpuidset", "00000001", "000106e5", "00100800", "0098e3fd", "bfebfbff"]
        provider.customize ["modifyvm", :id, "--cpu-profile", "Intel Core i7-6700K"]
        provider.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
      else
        provider.memory = "4096"
        provider.cpus = 2
        provider.ssh_port = 22
      end
    end
    macos.vm.provision "shell", inline: <<-SHELL
      # Install Homebrew
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Add Homebrew to PATH
      (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zshrc
      eval "$(/opt/homebrew/bin/brew shellenv)"
      # Install Ansible
      brew install ansible
    SHELL
    macos.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "main.yml"
      ansible.extra_vars = {
        is_macos: true
      }
    end
  end
end
