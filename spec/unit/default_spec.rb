require 'spec_helper'

describe 'grafana::default' do
  platforms = {
    'debian' => {
      'versions' => ['7.4']
    },
    'ubuntu' => {
      'versions' => ['12.04', '14.04']
    },
    'centos' => {
      'versions' => ['6.4', '6.6']
    }
  }

  platforms.each do |platform, value|
    value['versions'].each do |version|
      context "on #{platform} #{version}" do
        before do
          stub_command("dpkg -l | grep '^ii' | grep grafana | grep 2.0.2")
          stub_command('yum list installed | grep grafana | grep 2.0.2')
        end
        context 'with default attributes' do
          before do
            stub_command 'which nginx'
          end

          let(:chef_run) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/var/chef/cache').converge described_recipe
          end

          it 'installs grafana package' do
            if platform == 'centos'
              expect(chef_run).to install_rpm_package("grafana-#{chef_run.node['grafana']['version']}")
            else
              expect(chef_run).to install_dpkg_package("grafana-#{chef_run.node['grafana']['version']}")
            end
          end

          it 'loads grafana::_nginx recipe' do
            expect(chef_run).to include_recipe 'grafana::_nginx'
          end

          it 'loads grafana::_install_file recipe' do
            expect(chef_run).to include_recipe 'grafana::_install_file'
          end

          it 'create log and data directories' do
            expect(chef_run).to create_directory('/var/lib/grafana').with(mode: '0755')
            expect(chef_run).to create_directory('/var/log/grafana').with(mode: '0755')
          end

          it 'generate grafana.ini' do
            expect(chef_run).to create_template('/etc/grafana/grafana.ini').with(
              mode: '0644',
              user: 'root'
            )
            expect(chef_run).to render_file('/etc/grafana/grafana.ini').with_content(%r{^data = /var/lib/grafana})
            expect(chef_run).to render_file('/etc/grafana/grafana.ini').with_content(/^host = 127.0.0.1:3306/)
          end

          it 'generate grafana-server environment vars' do
            expect(chef_run).to create_template('/etc/default/grafana-server')
          end

          it 'start and enable grafana-server service' do
            expect(chef_run).to enable_service('grafana-server')
            expect(chef_run).to start_service('grafana-server')
          end
        end

        context 'with no webserver' do
          let(:chef_run) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/var/chef/cache') do |node|
              node.set['grafana']['webserver'] = ''
            end.converge described_recipe
          end

          it 'installs grafana package' do
            if platform == 'centos'
              expect(chef_run).to install_yum_package 'initscripts'
              expect(chef_run).to install_yum_package 'fontconfig'
              expect(chef_run).to create_remote_file "/var/chef/cache/grafana-#{chef_run.node['grafana']['version']}.rpm"
              expect(chef_run).to install_rpm_package "grafana-#{chef_run.node['grafana']['version']}"
            else
              expect(chef_run).to install_apt_package 'adduser'
              expect(chef_run).to install_apt_package 'libfontconfig'
              expect(chef_run).to create_remote_file "/var/chef/cache/grafana-#{chef_run.node['grafana']['version']}.deb"
              expect(chef_run).to install_dpkg_package "grafana-#{chef_run.node['grafana']['version']}"
            end
          end

          it 'do not load grafana::nginx recipe' do
            expect(chef_run).not_to include_recipe 'grafana::_nginx'
          end

          it 'loads grafana::_install_file recipe' do
            expect(chef_run).to include_recipe 'grafana::_install_file'
          end

          it 'generate grafana.ini' do
            expect(chef_run).to create_template('/etc/grafana/grafana.ini').with(
              mode: '0644',
              user: 'root'
            )
            expect(chef_run).to render_file('/etc/grafana/grafana.ini').with_content(%r{^data = /var/lib/grafana})
            expect(chef_run).to render_file('/etc/grafana/grafana.ini').with_content(/^host = 127.0.0.1:3306/)
          end
        end
      end
    end
  end
end
