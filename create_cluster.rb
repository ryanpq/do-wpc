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

require 'io/console'

def yesno()
  case $stdin.getch
    when "Y" then true
    when "N" then false
    when "n" then false
    when "y" then true
    else 
      puts "Invalid character."
      yesno()
  end
end

session = DropletKit::Client.new(access_token: @token)
ssh_id_array = Array.new
session.ssh_keys.all().each { |x|  ssh_id_array.push(x) }
puts "PICK YOUR SSH KEY"
count = 1
ssh_id_array.each { |ssh_key| 
  puts "#{count.to_s} #{ssh_key.name} #{ssh_key.id}" 
  count += 1
  }

keys_complete = false
user_keys = []
while keys_complete == false
  puts "Please select a key:"
  user_input = gets.chomp()
  if user_input.to_i.between?(1,session.ssh_keys.all().count.to_i)
    if user_keys.include? user_input.to_i
      puts 'That key has already been selected'
    else
      user_keys.push(user_input)
    end
  else
    puts "You need to select a key from the list."
  end
  puts "Do you want to add any other keys? [Y/N]"
  if yesno()
    keys_complete = false
  else
    keys_complete = true
  end
end 
puts ssh_id_array[1]
user_keys.each { |keys_blah| 
  @ssh_keys.push(ssh_id_array[keys_blah.to_i-1].id)
}

# clear the screen
system('clear') or system('cls')

session = DropletKit::Client.new(access_token: @token)
ssh_id_array = Array.new
session.ssh_keys.all().each { |x|  ssh_id_array.push(x) }
puts "Enter which key you would like to use"
puts "-------------------------------------"
puts " "
count = 1
ssh_id_array.each { |ssh_key|
        puts "#{count.to_s} #{ssh_key.name} #{ssh_key.id}"
        count += 1
        }
puts "-------------------------------------"
ssh_keys = ssh_id_array[gets.chomp().to_i-1].id
#puts ssh_keys

system('clear') or system('cls')

puts "Multi-Node Wordpres Deployment Tool"
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
  puts "1.)  1GB RAM |   1 CPU Core |  30GB Disk |  $10/mo"
  puts "2.)  2GB RAM |  2 CPU Cores |  40GB Disk |  $20/mo"
  puts "3.)  4GB RAM |  2 CPU Cores |  60GB Disk |  $40/mo"
  puts "4.)  8GB RAM |  4 CPU Cores |  80GB Disk |  $80/mo"
  puts "5.) 16GB RAM |  8 CPU Cores | 160GB Disk | $160/mo"
  puts "6.) 32GB RAM | 12 CPU Cores | 320GB Disk | $320/mo"
  puts "7.) 48GB RAM | 16 CPU Cores | 480GB Disk | $480/mo"
  puts " "
  puts "Enter a number and press Enter."
  mysql_size_choice = gets.chomp().to_i
  
  if mysql_size_choice == 1
    mysql_size = '1gb'
  elsif mysql_size_choice == 2
    mysql_size = '2gb'
  elsif mysql_size_choice == 3
    mysql_size = '4gb'
  elsif mysql_size_choice == 4
    mysql_size = '8gb'
  elsif mysql_size_choice == 5
    mysql_size = '16gb'
  elsif mysql_size_choice == 6
    mysql_size = '32gb'  
  elsif mysql_size_choice == 7  
    mysql_size = '48gb'
  else
    mysql_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
  end
end

# Choose Number and size of GlusterFS Nodes
system('clear') or system('cls')
gluster_size = 0
while gluster_size == 0
  puts "What size droplet do you wish to use for your GlusterFS nodes?"
  puts " "
  puts "1.)  1GB RAM |   1 CPU Core |  30GB Disk |  $10/mo"
  puts "2.)  2GB RAM |  2 CPU Cores |  40GB Disk |  $20/mo"
  puts "3.)  4GB RAM |  2 CPU Cores |  60GB Disk |  $40/mo"
  puts "4.)  8GB RAM |  4 CPU Cores |  80GB Disk |  $80/mo"
  puts "5.) 16GB RAM |  8 CPU Cores | 160GB Disk | $160/mo"
  puts "6.) 32GB RAM | 12 CPU Cores | 320GB Disk | $320/mo"
  puts "7.) 48GB RAM | 16 CPU Cores | 480GB Disk | $480/mo"
  puts " "
  puts "Enter a number and press Enter."
  gluster_size_choice = gets.chomp().to_i
  
  if gluster_size_choice == 1
    gluster_size = '1gb'
  elsif gluster_size_choice == 2
    gluster_size = '2gb'
  elsif gluster_size_choice == 3
    
    gluster_size = '4gb'
  elsif gluster_size_choice == 4
    gluster_size = '8gb'
  elsif gluster_size_choice == 5
    gluster_size = '16gb'
  elsif gluster_size_choice == 6
    gluster_size = '32gb'  
  elsif gluster_size_choice == 7  
    gluster_size = '48gb'
  else
    gluster_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
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
  puts "2.) replicate = 2 - replicate all files on 2 nodes. Nodes must be created in multiples of 2"
  puts "3.) replicate = 3 - replicate all files on 3 nodes. Nodes must be created in multiples of 3"
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
  elsif gluster replica == 3
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
  puts "What size droplets do you wish to use for your Nginx web sever nodes?"
  puts " "
  puts "1.)  1GB RAM |   1 CPU Core |  30GB Disk |  $10/mo"
  puts "2.)  2GB RAM |  2 CPU Cores |  40GB Disk |  $20/mo"
  puts "3.)  4GB RAM |  2 CPU Cores |  60GB Disk |  $40/mo"
  puts "4.)  8GB RAM |  4 CPU Cores |  80GB Disk |  $80/mo"
  puts "5.) 16GB RAM |  8 CPU Cores | 160GB Disk | $160/mo"
  puts "6.) 32GB RAM | 12 CPU Cores | 320GB Disk | $320/mo"
  puts "7.) 48GB RAM | 16 CPU Cores | 480GB Disk | $480/mo"
  puts " "
  puts "Enter a number and press Enter."
  web_size_choice = gets.chomp().to_i
  
  if web_size_choice == 1
    web_size = '1gb'
  elsif web_size_choice == 2
    web_size = '2gb'
  elsif web_size_choice == 3
    
    web_size = '4gb'
  elsif web_size_choice == 4
    web_size = '8gb'
  elsif web_size_choice == 5
    web_size = '16gb'
  elsif web_size_choice == 6
    web_size = '32gb'  
  elsif web_size_choice == 7  
    web_size = '48gb'
  else
    web_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
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
  puts "1.)  1GB RAM |   1 CPU Core |  30GB Disk |  $10/mo"
  puts "2.)  2GB RAM |  2 CPU Cores |  40GB Disk |  $20/mo"
  puts "3.)  4GB RAM |  2 CPU Cores |  60GB Disk |  $40/mo"
  puts "4.)  8GB RAM |  4 CPU Cores |  80GB Disk |  $80/mo"
  puts "5.) 16GB RAM |  8 CPU Cores | 160GB Disk | $160/mo"
  puts "6.) 32GB RAM | 12 CPU Cores | 320GB Disk | $320/mo"
  puts "7.) 48GB RAM | 16 CPU Cores | 480GB Disk | $480/mo"
  puts " "
  puts "Enter a number and press Enter."
  lb_size_choice = gets.chomp().to_i
  
  if lb_size_choice == 1
    lb_size = '1gb'
  elsif lb_size_choice == 2
    lb_size = '2gb'
  elsif lb_size_choice == 3
    
    lb_size = '4gb'
  elsif lb_size_choice == 4
    lb_size = '8gb'
  elsif lb_size_choice == 5
    lb_size = '16gb'
  elsif lb_size_choice == 6
    lb_size = '32gb'  
  elsif lb_size_choice == 7  
    lb_size = '48gb'
  else
    lb_size = 0
    system('clear') or system('cls')
    puts "Invalid Droplet Size Selected.  Please try again."
    puts " "
  end
end

# Finally, get the datacenter to use.
system('clear') or system('cls')
datacenter = ''
while datacenter == ''
  puts "In which datacenter do you wish to deploy?"
  puts " "
  puts "1.) NYC3 - New York, NY"
  puts "2.) AMS2 - Amsterdam, NE"
  puts "3.) LON1 - London, UK"
  puts "4.) SGP1 - Singapore"
  puts "5.) SFO1 - San Francisco, CA"
  puts "6.) FRA1 - Frankfurt, DE"
  
  puts " "
  dc_choice = gets.chomp().to_i
  if dc_choice == 1
    datacenter = 'nyc3'
  elsif dc_choice == 2
    datacenter = 'ams2'
  elsif dc_choice == 3
    datacenter = 'lon1'
  elsif dc_choice == 4
    datacenter = 'sgp1'
  elsif dc_choice == 5
    datacenter = 'sfo1'
  elsif dc_choice == 6
    datacenter = 'fra1'
  else
    system("clear")
    puts "Invalid Option Selected.  Please try again:"
    datacenter = ''
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
