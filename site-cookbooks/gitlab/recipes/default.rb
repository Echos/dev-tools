#
# Cookbook Name:: gitlab
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

%w(git curl zlib-devel openssl-devel make gcc gdbm-devel readline-devel ncurses-devel libffi-devel libxml2-devel libxslt-devel libcurl-devel libicu-devel libyaml-devel autoconf libicu-devel mysql mysql-server mysql-devel mysql-libs redis nginx icu libicu-devel patch).each do |pkg|
	package pkg do
		action :install
	end
end

directory '/tmp/ruby' do
	owner 'root'
	group 'root'
	mode '755'
	action 'create'
	not_if "ls -la /tmp/ruby"
end

bash 'install-ruby' do
	not_if "ls -la /bin/ruby"
	code <<-EOC
		cd /tmp/ruby/
		curl -O #{node['ruby']['url']}
		tar zxvf *.tar.gz
		cd ruby*
		./configure --prefix=/
		make
		make install
		EOC
		user "root"
		group "root"
end

ENV['PATH'] = "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"

bash 'install gems' do
	code <<-EOC
		/bin/gem install bundler
	EOC
	user 'root'
	group 'root'
end

u = node["gitlab"]["user"]

user u do
	home "/home/#{u}"
	shell "/bin/bash"
	password nil
	supports :manage_home => true
	action :create
end

directory "/home/#{u}/.ssh" do
	owner "#{u}"
	group "#{u}"
	mode 00700
	action :create
end

file "/home/#{u}/.ssh/authorized_keys" do
	owner "#{u}"
	group "#{u}"
	mode 00600
	action :create
end

execute 'set git config' do
	user "#{u}"
	group "#{u}"
	environment ({'HOME' => "/home/#{u}"})
	command <<-EOC
			git config --global user.name  "GitLab"
			git config --global user.email "gitlab@git.example.jp"
	EOC
end

git "/home/#{u}/gitlab-shell" do
	repository "https://github.com/gitlabhq/gitlab-shell.git"
	reference "v1.4.0"
	action :checkout
	user "#{u}"
	group "#{u}"
end

git "/home/#{u}/gitlab" do
	repository "https://github.com/gitlabhq/gitlabhq.git"
	reference "checkout 5-2-stable"
	action :checkout
	user "#{u}"
	group "#{u}"
end

directory "/home/#{u}" do
	owner "#{u}"
	group "#{u}"
	mode '755'
end


%w(log tmp tmp/pids tmp/sockets public/uploads).each do |dir|
	directory "/home/#{u}/gitlab/#{dir}" do
		owner "#{u}"
		group "#{u}"
		mode '777'
		action 'create'
		recursive true
		#not_if "ls -al /home/#{u}/gitlab/#{dir}"
	end
end

template "config.yml" do
	path "/home/#{u}/gitlab-shell/config.yml"
	source "config.yml.erb"
	owner "#{u}"
	group "#{u}"
	mode "0644"
end

execute 'init gitlab-shell' do
	user "#{u}"
	group "#{u}"
	environment ({'HOME' => "/home/#{u}"})
	cwd "/home/#{u}/gitlab-shell"
	ignore_failure true
	command <<-EOC
		./bin/install
	EOC
end

%w(gitlab.yml unicorn.rb database.yml puma.rb).each do |file|
	template "#{file}" do
		path "/home/#{u}/gitlab/config/#{file}"
		source "#{file}.erb"
		owner "#{u}"
		group "#{u}"
		mode "0644"
	end
end

directory '/home/git/gitlab-satellites' do
	owner "#{u}"
	group "#{u}"
	mode '755'
	action 'create'
	not_if "ls -la /home/git/gitlab-satellites"
end

directory '/home/git/gitlab/tmp/pids' do
	owner "#{u}"
	group "#{u}"
	mode '755'
	action 'create'
	not_if 'ls -la /home/git/gitlab/tmp/pids'
end


template "my.cnf" do
	path "/etc/my.cnf"
	source "my.cnf.erb"
	owner "root"
	group "root"
	mode "0644"
end

%w(createdb.sql).each do |file|
	cookbook_file "/tmp/#{file}" do
		source file
		owner "root"
		group "root"
		mode "755"
	end
end

%w(mysqld redis nginx).each do |service|
	service service do
		supports :status=>true , :restart=>true , :reload => true
		action [:enable, :start ]
	end
end

execute 'init mysql' do
	user 'root'
	group 'root'
	cwd "/tmp"
	ignore_failure true
	command <<-EOC
			mysql < createdb.sql
	EOC
end

execute 'execute bundler for gitlab' do
	user "#{u}"
	group "#{u}"
	environment ({'HOME' => "/home/#{u}"})
	cwd "/home/#{u}/gitlab"
	#command "yes yes | ./make_gitlab.sh"
	command <<-EOH
		yes yes | /bin/bundle install --deployment --without development test postgres
		yes yes | /bin/bundle exec /bin/rake gitlab:setup RAILS_ENV=production
		yes yes | /bin/bundle exec /bin/rake gitlab:env:info RAILS_ENV=production
		yes yes | /bin/bundle exec /bin/rake gitlab:check RAILS_ENV=production
	EOH
end

template "init.d setting for gitlab" do
	path "/etc/init.d/gitlab"
	source "init.d.gitlab.erb"
	owner "root"
	group "root"
	mode "0755"
end

template "nginx settiong for gitlab" do
	path "/etc/nginx/conf.d/gitlab.conf"
	source "nginx.gitlab.conf.erb"
	owner "root"
	group "root"
	mode "0755"
end

service 'gitlab' do
	supports :status=>true , :restart=>true , :reload => true
	action [:enable, :start ]
	not_if { ::File.exist? ("/home/git/gitlab/tmp/sockets/gitlab.sockets") }
end

service 'iptables' do
	supports :status=>true , :restart=>true , :reload => true
	action [:disable, :stop ]
end

execute 'nginx config test' do
	user 'root'
	group 'root'
	command <<-EOC
		/etc/init.d/nginx configtest
	EOC
end

service 'nginx' do
	action :restart
end


directory "/home/#{u}" do
	owner "#{u}"
	group "#{u}"
	mode '755'
end

