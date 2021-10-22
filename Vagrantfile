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
sudo dnf install -y unzip curl vim jq

echo "Installing Nomad..."
NOMAD_VERSION=1.1.6
cd /tmp/
curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip
unzip nomad.zip
sudo install nomad /usr/bin/nomad
sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d

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
(
cat <<-EOF
  [Unit]
  Description=consul agent
  Requires=network-online.target
  After=network-online.target

  [Service]
  Restart=on-failure
  ExecStart=/usr/bin/consul agent -dev
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

SCRIPT

Vagrant.configure(2) do |config|
  config.vm.box = "fedora/34-cloud-base"
  config.vm.hostname = "nomad"
  config.vm.provision "shell", inline: $script, privileged: false

  # Expose the nomad api and ui to the host
  config.vm.network "forwarded_port", guest: 4646, host: 9646, auto_correct: true, host_ip: "127.0.0.1"

  # Use libvirt provider and allocate resources
  config.vm.provider :libvirt do |v|
    v.cpus = 2
    v.memory = 2048
  end
end