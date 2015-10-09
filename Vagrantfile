Vagrant.configure(2) do |config|

  root = File.dirname(__FILE__)
  project_name = root.split("/").last

  config.vm.box = "mechfish/precise64-ruby"
  config.vm.synced_folder ".", "/home/vagrant/#{project_name}"
  config.vm.provision "shell", binary: true, inline: <<-SHELL
    sudo gem install os ffi
    echo \"export LIBRARY_PATH=\\"#{File.join(root, 'xxx')}\\"\" >> .bashrc
    echo \"cd #{project_name}\" >> .bashrc
  SHELL

end
