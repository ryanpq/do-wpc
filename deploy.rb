# deploy.rb

def createDomainDNS()
  
end

def createArecord(name,ip)
  
end

def deployMySQL(droplet_size)
  sitename = "mysql.#{@domain}"
  image_slug = 'ubuntu-14-04-x64'
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
sed -i.bak "s/127.0.0.1/$PRIVATE_IP/g" /etc/mysql/my.cnf;
service mysql restart;
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
  mysql_info = {"public_ip" => public_ip, "private_ip" => private_ip}
  return mysql_info
end











def deployGluster(num_of_nodes,droplet_size,replica)
  image_slug = 'ubuntu-14-04-x64'
  sitename = "gluster1.#{@domain}"
  gluster_nodes = Array.new
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get install -y python-software-properties;
add-apt-repository -y ppa:gluster/glusterfs-3.5;
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
apt-get install -y python-software-properties;
add-apt-repository -y ppa:gluster/glusterfs-3.5;
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
apt-get install -y python-software-properties;
add-apt-repository -y ppa:gluster/glusterfs-3.5;
apt-get update;
apt-get install -y glusterfs-server;
sleep 30
#{gluster_peer_probes}
gluster volume create file_store #{replica_conf}transport tcp #{gluster_peers}$PRIVATE_IP:/gluster force;
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






def deployNginxWeb(num_of_nodes,gluster_mount,mysql_ip,droplet_size)
image_slug = 'ubuntu-14-04-x64'
sitename = "web1.#{@domain}"
# Create the first node and populate the gluster mount point with WP files.
userdata = <<-EOM
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive;
export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
export PRIVATE_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
apt-get update;
apt-get -y install nginx glusterfs-client php5-fpm;
sed -i s/\;cgi\.fix_pathinfo\=1/cgi\.fix_pathinfo\=0/g /etc/php5/fpm/php.ini;
mkdir /gluster;
mount -t glusterfs #{gluster_mount} /gluster;
mkdir /gluster/www;
sed -i s/\\/usr\\/share\\/nginx\\/html/gluster\\/www/g /etc/nginx/sites-enabled/default;
echo "<h1>Test</h1>" > /gluster/www/index.html;
service nginx restart;
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
  
  # Create a DNS record for this node
  puts " "
  puts "Web Server #1 Creation Complete."
  puts "Private IP: #{private_ip}"
  puts "Public IP: #{public_ip}"
  
end

def deployNginxLB(web_nodes)
  
end