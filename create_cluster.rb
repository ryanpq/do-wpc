#!/usr/bin/ruby
#
# script to create a MySQL/Nginx/GlusterFS/Wordpress cluster
# on DigitalOcean droplets
##############################################################
# Settings
@ssh_keys=[''] # ID of the ssh key(s) to use.
@token='' # DigitalOcean API Token
##############################################################
require 'droplet_kit'
require 'securerandom'
require './deploy.rb'
client = DropletKit::Client.new(access_token: @token)
sizes = client.sizes.all

# clear the screen
system('clear') or system('cls')

puts "Multi-Node Wordpress Deployment Tool"
puts "-----------------------------------"
puts " "
puts "This script will deploy a multi-node Wordpress instance including"
puts "a MySQL server, Multiple GlusterFS nodes, Nginx Web servers and an"
puts "Nginx proxy to route traffic."
puts " "
puts "To begin you will need:"
puts " "
puts "- A domain name for which DNS records will be created"
puts "- Information on the number and size of web and Gluster nodes you wish to create"
puts " "
puts "Press Enter to Begin or Ctrl+c to quit."
gets.chomp()


# Choose Domain Name
system('clear') or system('cls')
domain = ''
while domain == ''
  puts "Enter a domain name for this deployment."
  puts "This domain should not already be configured in"
  puts "DigitalOcean's DNS service."
  puts " "
  puts "A DNS record will be created for this domain and "
  puts "records will be created for each droplet this tool creates."
  puts " "
  domain = gets.chomp()
end

@domain = domain

# Choose MySQL Droplet Size
system('clear') or system('cls')
mysql_size = 0
while mysql_size == 0
  puts "What size droplet do you wish to use for your MySQL server?"
  puts " "
  sizes.each_with_index do |size,index|
    if size.memory/1024 == 0
      next
    end
    puts "#{index}.) #{size.memory/1024}GB RAM | #{size.vcpus} CPU | #{size.disk}GB Disk | #{size.transfer}GB Transfer $#{(size.price_monthly).to_i}/mo (#{size.slug})"
  end
  puts " "
  puts "Enter a number and press Enter."
  mysql_size_choice = gets.chomp().to_i
  
  if mysql_size_choice >= sizes.count || mysql_size_choice < 1
    mysql_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
  else
    mysql_size = sizes[mysql_size_choice].slug
  end
end

# Choose Number and size of GlusterFS Nodes
system('clear') or system('cls')
gluster_size = 0
while gluster_size == 0
  puts "What size droplet do you wish to use for your GlusterFS nodes?"
  puts " "
  sizes.each_with_index do |size,index|
    if size.memory/1024 == 0
      next
    end
    puts "#{index}.) #{size.memory/1024}GB RAM | #{size.vcpus} CPU | #{size.disk}GB Disk | #{size.transfer}GB Transfer $#{(size.price_monthly).to_i}/mo (#{size.slug})"
  end
  puts " "
  puts "Enter a number and press Enter."
  gluster_size_choice = gets.chomp().to_i
  
  if gluster_size_choice >= sizes.count || gluster_size_choice < 1
    gluster_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
  else
    gluster_size = sizes[gluster_size_choice].slug
  end
end
system('clear') or system('cls')
gluster_replica = 0
while gluster_replica == 0
  puts "GlusterFS can be configured to replicate your data across multiple nodes"
  puts "or can be configured simply as a static storage space.  Please select a "
  puts "replication setting for your GlusterFS cluster."
  puts " "
  puts "1.) No replication, use all available disk space."
  puts "2.) replicate = 2 - replicate all files on 2 nodes. Nodes must be created in multiples of 2 (Not recommended!)"
  puts "3.) replicate = 3 - replicate all files on 3 nodes. Nodes must be created in multiples of 3 (Recommended)"
  puts " "
  puts "Enter a number and press Enter to continue."
  gluster_replica_count = gets.chomp().to_i
  if gluster_replica_count > 0 and gluster_replica_count < 4
    gluster_replica = gluster_replica_count;
  else
    gluster_replica = 0
    system('clear') or system('cls')
    puts "Invalid entry, please try again."
    puts " "
  end
  
end

system('clear') or system('cls')
gluster_count = 0
while gluster_count == 0
  puts "How many GlusterFS nodes do you wish to create?"
  if gluster_replica == 1
    puts "Enter a number of nodes to create:"
  elsif gluster_replica == 2
    puts "Enter a number of nodes to create (must be a multiple of 2):"
  elsif gluster_replica == 3
    puts "Enter a number of nodes to create (must be a multiple of 3):"
  else
    puts "ERROR: Gluster Replica Count is not valid."
    exit
  end
  puts " "
  gluster_node_count = gets.chomp().to_i
  if gluster_replica == 2
    if gluster_node_count % 2 > 0
      gluster_count = 0
      system('clear') or system('cls')
      puts "#{gluster_node_count} is not a multiple of 2."
      puts " "
    else
      gluster_count = gluster_node_count
    end   
  elsif gluster_replica == 3
    if gluster_node_count % 3 > 0
      gluster_count = 0
      system('clear') or system('cls')
      puts "#{gluster_node_count} is not a multiple of 3."
      puts " "
    else
      gluster_count = gluster_node_count
    end
    
  elsif gluster_replica == 1
    gluster_count = gluster_node_count
  else
    puts "ERROR: gluster_replica = #{gluster_replica}. Invalid option."
  end
  
  
end
# Choose Number and size of nginx web nodes
system('clear') or system('cls')
web_size = 0
while web_size == 0
  puts "What size droplets do you wish to use for your Nginx web server nodes?"
  puts " "
  sizes.each_with_index do |size,index|
    if size.memory/1024 == 0
      next
    end
    puts "#{index}.) #{size.memory/1024}GB RAM | #{size.vcpus} CPU | #{size.disk}GB Disk | #{size.transfer}GB Transfer $#{(size.price_monthly).to_i}/mo (#{size.slug})"
  end
  puts " "
  puts "Enter a number and press Enter."
  web_size_choice = gets.chomp().to_i
  
  if web_size_choice >= sizes.count || web_size_choice < 1
    web_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
  else
    web_size = sizes[web_size_choice].slug
  end
end
system('clear') or system('cls')
web_count = 0
while web_count == 0
  puts "How many web server nodes would you like to create?"
  puts " "
  puts "Enter a number and press Enter."
  puts " "
  web_count = gets.chomp()
end

# Choose size of nginx load balancer
system('clear') or system('cls')
lb_size = 0
while lb_size == 0
  puts "What size droplet do you wish to use for your nginx load balancer?"
  puts " "
  sizes.each_with_index do |size,index|
    if size.memory/1024 == 0
      next
    end
    puts "#{index}.) #{size.memory/1024}GB RAM | #{size.vcpus} CPU | #{size.disk}GB Disk | #{size.transfer}GB Transfer $#{(size.price_monthly).to_i}/mo (#{size.slug})"
  end
  puts " "
  puts "Enter a number and press Enter."
  lb_size_choice = gets.chomp().to_i
  
  if lb_size_choice >= sizes.count || lb_size_choice < 1
    lb_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
  else
    lb_size = sizes[lb_size_choice].slug
  end
end

# Finally, get the datacenter to use.
system('clear') or system('cls')
datacenter = ''
regions = client.regions.all
while datacenter == ''
  puts "In which datacenter do you wish to deploy?"
  puts " "
  regions.each_with_index do |region,index|
    thisIndex = index + 1
    puts "#{thisIndex}.) #{region.slug.upcase} - #{region.name}"
  end
  puts " "
  puts "Enter a number and press Enter."
  dc_choice = gets.chomp().to_i
  
  if dc_choice > regions.count || dc_choice < 1
    system("clear")
    puts "Invalid Option Selected.  Please try again:"
    datacenter = ''
  else
    datacenter = regions[dc_choice - 1].slug
  end
  
end

system('clear') or system('cls')
puts "The following nodes will be created for your deployment:"
puts " "
puts "1x MySQL Database - #{mysql_size}"
puts "#{gluster_count.to_s}x GlusterFS Nodes - #{gluster_size}"
puts "#{web_count.to_s}x Nginx Web Server Nodes - #{web_size}"
puts "1x Nginx Load Balancer - #{lb_size}"
puts " "
puts "These nodes will be deployed under the domain #{domain} in the #{datacenter} datacenter."
puts " "
puts "Press Enter to begin your deployment or Ctrl+c to Cancel"
gets.chomp()
@region = datacenter
@domain = domain

@zone = {}
@a_records = []


mysqlInfo = deployMySQL(mysql_size)
a_rec = {"name" => 'mysql', "ip" => mysqlInfo["public_ip"]}
@a_records.push(a_rec)
mysql_private_ip = mysqlInfo["private_ip"]
mysql_pass = mysqlInfo["mysql_pass"]

glusterInfo = deployGluster(gluster_count, gluster_size, gluster_replica)
gluster_mount = glusterInfo[:mount]


web_servers = deployNginxWeb(web_count,gluster_mount,mysql_private_ip,web_size,mysql_pass)
lbip = deployNginxLB(web_servers,lb_size)
createDomainDNS(@domain,lbip)
a_rec = {"name" => 'www', "ip" => lbip}
@a_records.push(a_rec)

@a_records.each {|record|
 name = record["name"]
 ip = record["ip"]
 createArecord(@domain,name,ip)
}


puts "Deploy Complete! You can view your new site at:  http://#{lbip}"
