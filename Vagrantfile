Vagrant.configure(2) do |config|

  project_name = File.dirname(__FILE__).split("/").last

  config.vm.box = "ubuntu/trusty64"
  config.vm.synced_folder ".", "/home/vagrant/#{project_name}"
  config.vm.provision "shell", binary: true, inline: <<-SHELL
    sudo apt-get install -y libgmp-dev libgflags-dev
    sudo apt-get remove -y ruby
    command curl -sSL https://rvm.io/mpapis.asc | gpg --import -
    curl -sSL https://get.rvm.io | bash -s stable
    source /etc/profile.d/rvm.sh
    rvm install 2.2.3
    gem install os ffi
    echo \"export LIBRARY_PATH=\\"/home/vagrant/#{project_name}/xxx\\"\" >> .bashrc
    echo \"cd #{project_name}\" >> .bashrc
  SHELL

end
