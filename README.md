# do-wpc

![](http://i.imgur.com/ywvlGmJ.png)

This script was created based on the DigitalOcean tutorial which can be found [here](https://www.digitalocean.com/community/tutorials/automating-the-deployment-of-a-scalable-wordpress-site).

This script will create a scalable Wordpress deployment consisting of a MySQL server, multiple GlusterFS nodes, multiple nginx web server nodes and an Nginx load balancer using the DigitalOcean API, user-data and droplet meta-data.

This script requires the [droplet_kit](https://github.com/digitalocean/droplet_kit) gem 

To-Do:
- Additional Security measures on servers (iptables, fail2ban, etc)

### To Use this script

First install the droplet_kit gem

```
gem install droplet_kit
```

Then run create_cluster.rb

```
ruby create_cluster.rb
```
