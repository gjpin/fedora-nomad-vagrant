# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
echo "Installing Docker..."
sudo dnf update -y
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo usermod -aG docker vagrant
sudo docker --version

# Packages required for nomad & consul
sudo dnf install -y unzip curl vim jq nano

echo "Installing CNI plugins..."
cd /tmp/
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz
echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables
(
cat <<-EOF
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
) | sudo tee /etc/sysctl.d/cni-plugins.conf

# Create folder for wordpress host volume
sudo mkdir -p /var/lib/mariadb

echo "Installing Nomad..."
NOMAD_VERSION=1.1.6
curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip
unzip nomad.zip
sudo install nomad /usr/bin/nomad
sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d

(
cat <<-EOF
data_dir = "/opt/nomad/data"

datacenter = "dc1"

bind_addr = "0.0.0.0"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true

  cni_path = "/opt/cni/bin"

  host_volume "wordpress-mariadb" {
    path      = "/var/lib/mariadb"
    read_only = false
  }
}

plugin "docker" {
  config {
    extra_labels = ["job_name", "job_id", "task_group_name", "task_name", "namespace", "node_name", "node_id"]

    volumes {
      enabled = true
      selinuxlabel = "z"
    }

    allow_privileged = false
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

telemetry {
  collection_interval = "5s"
  disable_hostname = false
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
EOF
) | sudo tee /etc/nomad.d/nomad.hcl

(
cat <<-EOF
  [Unit]
  Description=nomad agent
  Requires=network-online.target
  After=network-online.target

  [Service]
  Restart=on-failure
  ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
  ExecReload=/bin/kill -HUP $MAINPID

  [Install]
  WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/nomad.service
sudo systemctl enable nomad.service
sudo systemctl start nomad

echo "Installing Nomad Pack..."
NOMAD_PACK_VERSION=0.0.1
curl -sSL https://releases.hashicorp.com/nomad-pack/${NOMAD_PACK_VERSION}-techpreview1/nomad-pack_${NOMAD_PACK_VERSION}-techpreview1_linux_amd64.zip -o nomad-pack.zip
unzip nomad-pack.zip
sudo install nomad-pack /usr/bin/nomad-pack

echo "Installing Consul..."
CONSUL_VERSION=1.10.3
curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > consul.zip
unzip consul.zip
sudo install consul /usr/bin/consul
sudo mkdir -p /etc/consul.d
sudo chmod a+w /etc/consul.d

(
cat <<-EOF
datacenter = "dc1"

data_dir = "/opt/consul"

ui_config {
  enabled = true
}

server = true

bootstrap_expect = 1

# Enable Consul Connect
ports {
  grpc = 8502
}

connect {
  enabled = true
}
EOF
) | sudo tee /etc/consul.d/consul.hcl

(
cat <<-EOF
  [Unit]
  Description=consul agent
  Requires=network-online.target
  After=network-online.target

  [Service]
  Restart=on-failure
  ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/ -bind '{{ GetInterfaceIP "eth0" }}'
  ExecReload=/bin/kill -HUP $MAINPID

  [Install]
  WantedBy=multi-user.target
EOF
) | sudo tee /etc/systemd/system/consul.service

sudo systemctl enable consul.service
sudo systemctl start consul

for bin in cfssl cfssl-certinfo cfssljson
do
  echo "Installing $bin..."
  curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
  sudo install /tmp/${bin} /usr/local/bin/${bin}
done
nomad -autocomplete-install

echo "Installing go and make..."
sudo dnf install -y go make
SCRIPT

Vagrant.configure(2) do |config|
  config.vm.box = "fedora/34-cloud-base"
  config.vm.hostname = "nomad"
  config.vm.provision "shell", inline: $script, privileged: false

  # Expose the nomad api and ui to the host
  config.vm.network "forwarded_port", guest: 4646, host: 9646, auto_correct: true, host_ip: "127.0.0.1"
  # Expose the consul api and ui to the host
  config.vm.network "forwarded_port", guest: 8500, host: 10500, auto_correct: true, host_ip: "127.0.0.1"

  # Use libvirt provider and allocate resources
  config.vm.provider :libvirt do |v|
    v.cpus = 2
    v.memory = 2048
  end
end
