Vagrant.configure(2) do |config|

  project_name = File.dirname(__FILE__).split("/").last

  config.vm.box = "mechfish/precise64-ruby"
  config.vm.synced_folder ".", "/home/vagrant/#{project_name}"
  config.vm.provision "shell", inline: <<-SHELL
    sudo gem install os ffi
    echo \"cd #{project_name}\" >> .bashrc
  SHELL

end
