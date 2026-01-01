require "yaml"
vagrant_root = File.dirname(File.expand_path(__FILE__))
settings_path = File.join(vagrant_root, "settings.yaml")
alt_settings_path = File.join(vagrant_root, "ansible-deploy-full-zabbix", "settings.yaml")
settings_file = File.exist?(settings_path) ? settings_path : alt_settings_path

# Processar o settings.yaml e substituir variáveis de ambiente
settings_raw = File.read(settings_file)
settings_processed = settings_raw.gsub(/\$\{(\w+)\}/) { ENV[$1] || "" }
settings = YAML.load(settings_processed)
control_ip = settings.dig("network", "control_ip")
control_ip = "10.0.0.22" if control_ip.nil? || control_ip.strip == ""

Vagrant.configure("2") do |config|
  # Specify the box (allow override via VAGRANT_BOX)
  is_arm = (RUBY_PLATFORM.include?("arm64") || RUBY_PLATFORM.include?("aarch64"))
  default_box = is_arm ? "bento/oraclelinux-9" : "eurolinux-vagrant/oracle-linux-9"
  config.vm.box = ENV.fetch("VAGRANT_BOX", default_box)

  # Configuração da máquina virtual principal
  config.vm.define "zabbixlnx01" do |zabbixlnx01|
    zabbixlnx01.vm.hostname = "zabbixlnx01"
    zabbixlnx01.vm.network "private_network", ip: control_ip
    host_http_port = (ENV["VAGRANT_HTTP_PORT"] || "80").to_i
    host_https_port = (ENV["VAGRANT_HTTPS_PORT"] || "443").to_i
    zabbixlnx01.vm.network "forwarded_port", guest: 80, host: host_http_port
    zabbixlnx01.vm.network "forwarded_port", guest: 443, host: host_https_port

    zabbixlnx01.vm.provider "virtualbox" do |vb|
      vb.cpus = settings["nodes"]["control"]["cpu"]
      vb.memory = settings["nodes"]["control"]["memory"]
    end

    # Desativar pasta sincronizada
    zabbixlnx01.vm.synced_folder ".", "/vagrant", disabled: true
  end
end
