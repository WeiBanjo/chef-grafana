#
# Cookbook Name:: grafana
# Recipe:: default
#
# Copyright 2014, Jonathan Tron
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

unless node['grafana']['webserver'].empty?
  include_recipe "grafana::_#{node['grafana']['webserver']}"
end

if node['grafana']['manage_install']
  include_recipe "grafana::_install_#{node['grafana']['install_type']}"
end

g_service = service 'grafana-server' do
  supports start: true, stop: true, restart: true, status: true, reload: false
  action :enable
end

directory node['grafana']['data_dir'] do
  owner node['grafana']['user']
  group node['grafana']['group']
  mode '0755'
  action :create
end

directory node['grafana']['log_dir'] do
  owner node['grafana']['user']
  group node['grafana']['group']
  mode '0755'
  action :create
end

g_default_template = template '/etc/default/grafana-server' do
  source 'grafana-env.erb'
  variables(
    grafana_user: node['grafana']['user'],
    grafana_group: node['grafana']['group'],
    grafana_home: node['grafana']['home'],
    log_dir: node['grafana']['log_dir'],
    data_dir: node['grafana']['data_dir'],
    conf_dir: node['grafana']['conf_dir']
  )
  owner 'root'
  group 'root'
  mode '0644'
end

ini = node['grafana']['ini'].to_hash
ini['paths'] ||= {}
ini['paths']['data'] = node['grafana']['data_dir']
ini['paths']['logs'] = node['grafana']['log_dir']

if node['grafana'].key?('database_databag')
  databag_info = node['grafana']['database_databag']
  bag = Chef::EncryptedDataBagItem.load(databag_info['databag_name'], databag_info['databag_key'])
  ini['database']['password'] = bag[ini['database']['user']]

  if ini.key?('session') and ini['session'].key?('provider') and ini['session']['provider'] == 'mysql'
    ini['session']['provider_config'] = "#{ini['database']['user']}:#{ini['database']['password']}@tcp(#{ini['database']['host']})/grafana"
  end
end

g_ini_template = template "#{node['grafana']['conf_dir']}/grafana.ini" do
  source 'grafana.ini.erb'
  variables ini: ini
  owner node['grafana']['user']
  group node['grafana']['group']
  sensitive true
  mode '0600'
end

ruby_block 'restart grafana immediately after config change' do
  block { g_service.run_action :restart }
  only_if do
    g_default_template.updated_by_last_action? ||
      g_ini_template.updated_by_last_action?
  end
end

unless node['grafana']['ini']['auth.ldap']['enabled']['value'] == false
  include_recipe 'grafana::_ldap_config'
end
