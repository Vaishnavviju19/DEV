#!/bin/bash
 
# Update package lists
sudo apt update -y
 
# Install required dependencies for Docker installation
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
 
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 
# Add Docker repository to the APT sources list
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
 
# Update package lists again to include Docker repository
sudo apt update -y
 
# Check Docker version and available installation options
apt-cache policy docker-ce
 
# Install Docker Community Edition (docker-ce)
sudo apt install docker-ce -y
 
# Check the status of the Docker service
sudo systemctl status docker
