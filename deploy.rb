# deploy.rb

def createDomainDNS(domain,ip)
  puts "Creating DNS entry for #{domain}"
  new_domain = DropletKit::Domain.new(name: domain, ip_address: ip)
  client = DropletKit::Client.new(access_token: @token)
  client.domains.create(new_domain)
end

def createArecord(domain,name,ip)
  puts "Creating A record for #{name} pointing to #{ip}"
  client = DropletKit::Client.new(access_token: @token)
  domain_record = DropletKit::DomainRecord.new(
  type: 'A',
  name: name,
  data: ip
)
client.domain_records.create(domain_record, for_domain: @domain)
end

def deployMySQL(droplet_size)
  sitename = "mysql.#{@domain}"
  image_slug = 'ubuntu-18-04-x64'
  mysql_pass = SecureRandom.hex
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get -y install mysql-server;
mysqladmin -u root create wordpress;
mysqladmin -u root password "#{mysql_pass}";
sed -i.bak "s/127.0.0.1/$PRIVATE_IP/g" /etc/mysql/mysql.conf.d/mysqld.cnf;
service mysql restart;
mysql -uroot -p#{mysql_pass} -e "CREATE USER 'wordpress'@'%' IDENTIFIED BY '#{mysql_pass}'";
mysql -uroot -p#{mysql_pass} -e "GRANT ALL ON wordpress.* TO 'wordpress'@'%'";
EOM
  client = DropletKit::Client.new(access_token: @token)
  droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
  create = client.droplets.create(droplet)
  
  createid = create.id.to_s
  
  puts " "
  print "Creating MySQL Server..."
  create_complete = 0
  while create_complete != 1 do
    print "."
    dobj = client.droplets.find(id: createid)

    if dobj.status == 'active'
  
      create_complete = 1
    else
      print "."
    end
    sleep(5) 
  end
  
  if dobj.networks.v4[0].type == 'private'
    private_ip = dobj.networks.v4[0].ip_address
    public_ip = dobj.networks.v4[1].ip_address
  else
    private_ip = dobj.networks.v4[1].ip_address
    public_ip = dobj.networks.v4[0].ip_address
  end
  
  # Create a DNS record for this node
  puts " "
  puts "MySQL Server Creation Complete."
  puts "Private IP: #{private_ip}"
  puts "Public IP: #{public_ip}"
  mysql_info = {"public_ip" => public_ip, "private_ip" => private_ip, "mysql_pass" => mysql_pass}
  return mysql_info
end











def deployGluster(num_of_nodes,droplet_size,replica)
  image_slug = 'ubuntu-18-04-x64'
  sitename = "gluster1.#{@domain}"
  gluster_nodes = Array.new
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get install -y software-properties-common;
add-apt-repository -y ppa:gluster/glusterfs-3.13;
apt-get update;
apt-get install -y glusterfs-server;
EOM

  client = DropletKit::Client.new(access_token: @token)
  droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
  create = client.droplets.create(droplet)
  
  createid = create.id.to_s
  
  puts " "
  print "Creating GlusterFS Server #1..."
  create_complete = 0
  while create_complete != 1 do
    print "."
    dobj = client.droplets.find(id: createid)

    if dobj.status == 'active'
  
      create_complete = 1
    else
      print "."
    end
    sleep(5) 
  end
  
  if dobj.networks.v4[0].type == 'private'
    private_ip = dobj.networks.v4[0].ip_address
    public_ip = dobj.networks.v4[1].ip_address
  else
    private_ip = dobj.networks.v4[1].ip_address
    public_ip = dobj.networks.v4[0].ip_address
  end
  
  a_rec = {"name" => 'gluster1', "ip" => public_ip}
  @a_records.push(a_rec)
  
  puts " "
  puts "GlusterFS Node 1 Creation Complete."
  puts "Private IP: #{private_ip}"
  puts "Public IP: #{public_ip}"
  gluster_node = {"public_ip" => public_ip, "private_ip" => private_ip}
  gluster_nodes.push(gluster_node)
  
  
# First node created, now create any others that are required.
nct = 2
if num_of_nodes.to_i > 2
  nn = num_of_nodes.to_i - 2
  nn.times do
    sitename = "gluster#{nct}.#{@domain}"
    firstnode_ip = gluster_nodes[0]['private_ip']
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get install -y software-properties-common;
add-apt-repository -y ppa:gluster/glusterfs-3.13;
apt-get update;
apt-get install -y glusterfs-server;
EOM
    client = DropletKit::Client.new(access_token: @token)
    droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
    create = client.droplets.create(droplet)
    
    createid = create.id.to_s
    
    puts " "
    print "Creating GlusterFS Server ##{nct}..."
    create_complete = 0
    while create_complete != 1 do
      print "."
      dobj = client.droplets.find(id: createid)
  
      if dobj.status == 'active'
    
        create_complete = 1
      else
        print "."
      end
      sleep(5) 
    end
    
    if dobj.networks.v4[0].type == 'private'
      private_ip = dobj.networks.v4[0].ip_address
      public_ip = dobj.networks.v4[1].ip_address
    else
      private_ip = dobj.networks.v4[1].ip_address
      public_ip = dobj.networks.v4[0].ip_address
    end
    puts " "
    puts "GlusterFS Node #{nct} Creation Complete."
    puts "Private IP: #{private_ip}"
    puts "Public IP: #{public_ip}"
    gluster_node = {"public_ip" => public_ip, "private_ip" => private_ip}
    
  
    a_rec = {"name" => "gluster#{nct}", "ip" => public_ip}
    @a_records.push(a_rec)
    
    gluster_nodes.push(gluster_node)
    nct += 1
    
  end
end

# Now create the final node and add our volume
sitename = "gluster#{nct}.#{@domain}"
gluster_peer_probes = ''
gluster_peers = ''
gluster_nodes.each {|node|
  gluster_peer_probes += "gluster peer probe #{node["private_ip"]};"
  gluster_peers += "#{node["private_ip"]}:/gluster "
}

if replica == 1
  replica_conf = ''
  
else
  replica_conf = "replica #{replica}"
end


userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get install -y software-properties-common;
add-apt-repository -y ppa:gluster/glusterfs-3.13;
apt-get update;
apt-get install -y glusterfs-server;
sleep 40
#{gluster_peer_probes}
gluster volume create file_store #{replica_conf} transport tcp #{gluster_peers}$PRIVATE_IP:/gluster force;
gluster volume start file_store;
EOM
    client = DropletKit::Client.new(access_token: @token)
    droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
    create = client.droplets.create(droplet)
    
    createid = create.id.to_s
    
    puts " "
    print "Creating GlusterFS Server ##{nct}..."
    create_complete = 0
    while create_complete != 1 do
      print "."
      dobj = client.droplets.find(id: createid)
  
      if dobj.status == 'active'
    
        create_complete = 1
      else
        print "."
      end
      sleep(5) 
    end
    
    if dobj.networks.v4[0].type == 'private'
      private_ip = dobj.networks.v4[0].ip_address
      public_ip = dobj.networks.v4[1].ip_address
    else
      private_ip = dobj.networks.v4[1].ip_address
      public_ip = dobj.networks.v4[0].ip_address
    end
    
    a_rec = {"name" => "gluster#{nct}", "ip" => public_ip}
    @a_records.push(a_rec)
    puts " "
    puts "GlusterFS Node #{nct} Creation Complete."
    puts "Private IP: #{private_ip}"
    puts "Public IP: #{public_ip}"
    gluster_node = {"public_ip" => public_ip, "private_ip" => private_ip}
    gluster_nodes.push(gluster_node)
    nct += 1
    gmount_ip = gluster_nodes[0]["private_ip"]
    gmount = "#{gmount_ip}:/file_store"
    gluster_info = {nodes: gluster_nodes,mount: gmount}
    
    return gluster_info

end






def deployNginxWeb(num_of_nodes,gluster_mount,mysql_ip,droplet_size,mysql_pass)
  
  web_servers = []
  
  
image_slug = 'ubuntu-18-04-x64'
sitename = "web1.#{@domain}"
# Create the first node and populate the gluster mount point with WP files.
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get -y install nginx glusterfs-client php7.2-fpm php7.2-mysql php7.2-curl;
sed -i s/\;cgi\.fix_pathinfo\=1/cgi\.fix_pathinfo\=0/g /etc/php/7.2/fpm/php.ini;
mkdir /gluster;
mount -t glusterfs #{gluster_mount} /gluster;
echo "#{gluster_mount} /gluster glusterfs defaults,_netdev 0 0" >> /etc/fstab;
mkdir /gluster/www;
wget https://raw.githubusercontent.com/ryanpq/do-wpc/master/default -O /etc/nginx/sites-enabled/default;
service nginx restart;
# Get Wordpress Files
wget https://wordpress.org/latest.tar.gz -O /root/wp.tar.gz;
tar -zxf /root/wp.tar.gz -C /root/;
cp -Rf /root/wordpress/* /gluster/www/.;
cp /gluster/www/wp-config-sample.php /gluster/www/wp-config.php;
sed -i "s/'DB_NAME', 'database_name_here'/'DB_NAME', 'wordpress'/g" /gluster/www/wp-config.php;
sed -i "s/'DB_USER', 'username_here'/'DB_USER', 'wordpress'/g" /gluster/www/wp-config.php;
sed -i "s/'DB_PASSWORD', 'password_here'/'DB_PASSWORD', '#{mysql_pass}'/g" /gluster/www/wp-config.php;
sed -i "s/'DB_HOST', 'localhost'/'DB_HOST', '#{mysql_ip}'/g" /gluster/www/wp-config.php;
chown -Rf www-data:www-data /gluster/www;
EOM
    client = DropletKit::Client.new(access_token: @token)
    droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
    create = client.droplets.create(droplet)
    
    createid = create.id.to_s
    
    puts " "
    print "Creating Nginx Web Server #1..."
    create_complete = 0
    while create_complete != 1 do
      print "."
      dobj = client.droplets.find(id: createid)
  
      if dobj.status == 'active'
    
        create_complete = 1
      else
        print "."
      end
      sleep(5) 
    end
  if dobj.networks.v4[0].type == 'private'
    private_ip = dobj.networks.v4[0].ip_address
    public_ip = dobj.networks.v4[1].ip_address
  else
    private_ip = dobj.networks.v4[1].ip_address
    public_ip = dobj.networks.v4[0].ip_address
  end
  a_rec = {"name" => "web1", "ip" => public_ip}
  @a_records.push(a_rec)
  # Create a DNS record for this node
  puts " "
  puts "Web Server #1 Creation Complete."
  puts "Private IP: #{private_ip}"
  puts "Public IP: #{public_ip}"
  ws = {'public_ip' => public_ip,"private_ip" => private_ip}
  web_servers.push(ws)
  
# Now create the rest of the web nodes
if num_of_nodes.to_i > 1
  nct = 2
  nd = num_of_nodes.to_i - 1
  nd.times do
    sitename = "web#{nct}.#{@domain}"
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get -y install nginx glusterfs-client php7.2-fpm php7.2-mysql php7.2-curl;
sed -i s/\;cgi\.fix_pathinfo\=1/cgi\.fix_pathinfo\=0/g /etc/php/7.2/fpm/php.ini;
mkdir /gluster;
mount -t glusterfs #{gluster_mount} /gluster;
echo "#{gluster_mount} /gluster glusterfs defaults,_netdev 0 0" >> /etc/fstab;
mkdir /gluster/www;
wget https://raw.githubusercontent.com/ryanpq/do-wpc/master/default -O /etc/nginx/sites-enabled/default;
service nginx restart;
EOM
    
   client = DropletKit::Client.new(access_token: @token)
    droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
    create = client.droplets.create(droplet)
    
    createid = create.id.to_s
    
    puts " "
    print "Creating Nginx Web Server ##{nct}..."
    create_complete = 0
    while create_complete != 1 do
      print "."
      dobj = client.droplets.find(id: createid)
  
      if dobj.status == 'active'
    
        create_complete = 1
      else
        print "."
      end
      sleep(5) 
    end
  if dobj.networks.v4[0].type == 'private'
    private_ip = dobj.networks.v4[0].ip_address
    public_ip = dobj.networks.v4[1].ip_address
  else
    private_ip = dobj.networks.v4[1].ip_address
    public_ip = dobj.networks.v4[0].ip_address
  end
  a_rec = {"name" => "web#{nct}", "ip" => public_ip}
    @a_records.push(a_rec)
  
  # Create a DNS record for this node
  puts " "
  puts "Web Server ##{nct} Creation Complete."
  puts "Private IP: #{private_ip}"
  puts "Public IP: #{public_ip}" 
  ws = {'public_ip' => public_ip,"private_ip" => private_ip}
  web_servers.push(ws)
  nct += 1  
    
  end
  return web_servers
end

  
end

def deployNginxLB(web_servers,droplet_size)
  image_slug = 'ubuntu-18-04-x64'
  sitename = "www.#{@domain}"
  backends = ''
  web_servers.each {|server|
    p_ip = server["private_ip"]
    backends += "server #{p_ip};\n"
  }
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get -y install nginx;
lbconf="
server {
	listen 80 default_server;
	listen [::]:80 default_server ipv6only=on;

	root /usr/share/nginx/html;
	index index.php index.html index.htm;

	location / {
	  proxy_pass  http://backend;
	  include proxy_params;
	}

}

upstream backend  {
	ip_hash;
	#{backends}
}
"
echo $lbconf > /etc/nginx/sites-enabled/default;
service nginx restart;
EOM

client = DropletKit::Client.new(access_token: @token)
    droplet = DropletKit::Droplet.new(name: sitename, region: @region, size: droplet_size, image: image_slug, user_data: userdata, ssh_keys: @ssh_keys, private_networking: true)
    create = client.droplets.create(droplet)
    
    createid = create.id.to_s
    
    puts " "
    print "Creating Load Balancer..."
    create_complete = 0
    while create_complete != 1 do
      print "."
      dobj = client.droplets.find(id: createid)
  
      if dobj.status == 'active'
    
        create_complete = 1
      else
        print "."
      end
      sleep(5) 
    end
  if dobj.networks.v4[0].type == 'private'
    private_ip = dobj.networks.v4[0].ip_address
    public_ip = dobj.networks.v4[1].ip_address
  else
    private_ip = dobj.networks.v4[1].ip_address
    public_ip = dobj.networks.v4[0].ip_address
  end
  
  # Create a DNS record for this node
  puts " "
  puts "Load Balancer Creation Complete."
  puts "Private IP: #{private_ip}"
  puts "Public IP: #{public_ip}" 

  return public_ip
end