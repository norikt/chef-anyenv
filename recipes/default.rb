#
# Cookbook Name:: anyenv
# Recipe:: default
#
# Copyright 2015, uzyexe
#
# All rights reserved - Do Not Redistribute
#

node.default_unless['user']['name'] = node['current_user']
node.default_unless['user']['group'] = node['current_user']
node.default_unless['user']['home'] = node['etc']['passwd'][node['user']['name']]['dir']

# install required packages
case node['platform']
when 'debian', 'ubuntu'
  install_packages = %w{
    git
    gcc
    make
    openssl
    libssl-dev
    libbz2-dev
    libffi-dev
    libreadline-dev
    libsqlite3-dev
    curl
  }
when "centos", "redhat", "amazon", "scientific"
    install_packages = %w{
    gcc
    bzip2
    bzip2-devel
    libffi-devel
    openssl
    openssl-devel
    readline
    readline-devel
    curl
    git
  }
when "mac_os_x"
    install_packages = %w{
    git
  }
end

install_packages.each do |p|
  package p do
    action :install
  end
end

if node['platform'] == 'mac_os_x'
  # Support /etc/profile.d
  cookbook_file '/etc/profile' do
    source 'osx-profile'
    mode '0755'
  end

  # Add /etc/profile.d
  directory '/etc/profile.d' do
    owner 'root'
    mode '0755'
  end
end

template '/etc/profile.d/anyenv.sh' do
  source 'anyenv.sh.erb'
  owner 'root'
  mode '0755'
end

# install anyenv
execute 'install anyenv' do
  user node['user']['name']
  group node['user']['group']
  cwd  node['user']['home']
  environment "HOME" => node['user']['home']
  command "git clone https://github.com/riywo/anyenv $HOME/.anyenv"
  not_if { File.exist?("#{node['user']['home']}/.anyenv") }
end

# install *env
anyenvs = %w{plenv ndenv rbenv pyenv phpenv}
anyenvs.each do |install_env|
  bash install_env do
    user node['user']['name']
    group node['user']['group']
    cwd node['user']['home']
    environment "HOME" => node['user']['home']
    code <<-EOC
      . /etc/profile
      anyenv install #{install_env}
    EOC
    not_if { File.exist?("#{node['user']['home']}/.anyenv/envs/#{install_env}") }
  end
end

# install specified versions through *env
anyenv_map = {
  "perl"   => "plenv",
  "ruby"   => "rbenv",
  "node"   => "ndenv",
  "python" => "pyenv",
  "php"    => "phpenv",
}
anyenv_map.keys.each do |program|
  anyenv = node['anyenv']
  next unless anyenv.key?(program)
  anyenv[program]['versions'].each do |version|
    install_script = <<-EOC
      . /etc/profile
      #{anyenv_map[program]} install #{version}
    EOC
    install_script << "#{anyenv_map[program]} global #{version};" if version == anyenv[program]['global']

    execute "#{program} - #{version} at #{node['user']['home']}/.anyenv" do
      environment "HOME" => node['user']['home']
      user node['user']['name']
      group node['user']['group']
      command install_script
      not_if { File.exist?("#{node['user']['home']}/.anyenv/envs/#{anyenv_map[program]}/versions/#{version}") }
    end
  end
end
