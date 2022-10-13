# Continuous Deployment using Ansible Jenkins Git and Docker 
![diagram project](https://user-images.githubusercontent.com/17767960/195644178-9a03e3e8-c96e-454a-bbd3-a361294ce94c.png)

We are creating the infrastructure using Terraform

In this proect we are using infrastructure containing 3 servers

1. Jenkin Server
2. Build Server
3. Test Server

You can go through the main.tf file in this repository for the details of infrastructure create and we are also attaching role to the EC2 instance "jenkins" to read the AWS EC2 details from the infra

After adding the terraform code run
command 
```
terraform init 
```
![terraform init](https://user-images.githubusercontent.com/17767960/195647632-c67813ca-8fe7-4ae0-9f4f-632e275253c9.jpg)

After we can check our terraform code validation by running

```
terraform plan
```
![terraform plan](https://user-images.githubusercontent.com/17767960/195648013-354af007-0284-4241-8470-f856e9544d5f.jpg)

If everything is ready run
```
terraform apply
```

To build our infra in AWS

![terraform apply](https://user-images.githubusercontent.com/17767960/195648679-ce57bc69-4e1a-4a79-a7e2-134fb3fe8094.jpg)

Now we can verify our instances and details from AWS console and SSH to the jenkins server using your key 

![ec2 list](https://user-images.githubusercontent.com/17767960/195649253-dd84d520-fbd1-4002-843c-f4572dcc3f10.jpg)

After accessing the jenkis server run the commands to install the jenkin

```
sudo -i
wget -O /etc/yum.repos.d/jenkins.repo     https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum upgrade
amazon-linux-extras install java-openjdk11
yum install jenkins -y
service jenkins start
systemctl enable jenkins.service
```

To install git in the server jenkins

```
yum install git -y
```

Then we need to install Ansible and pyhton module boto to connect ansible with AWS infra in the jenkin server 

```
sudo amazon-linux-extras install python3.8 -y
pip3.8 install ansible boto boto3 botocore
```
After installing Ansible we can verify the Ansible installation
```
[ec2-user@ip-172-31-11-50 ~]$ which ansible
/usr/local/bin/ansible
```

Next we need to write our Ansible code to get the infra details from AWS and need to create a dynamic inventory to connect the Ansible with test server and build server

```
---
- name: "AWS inventory create"
  hosts: localhost
  tasks:

    - name: "Collect build ec2 instance"
      amazon.aws.ec2_instance_info:
        region: ap-south-1
        filters: 
          "tag:Name": build_server
          instance-state-name: [ "running"]
      register: ec2_build


    - name: "Collect build ec2 instance"
      amazon.aws.ec2_instance_info:
        region: ap-south-1
        filters: 
          "tag:Name": test_server
          instance-state-name: [ "running"]
      register: ec2_test

    - name: "build inventory"
      debug:
       msg: "instance ID : {{item.public_ip_address}}"
      with_items: "{{ec2_build.instances}}" 

    - name: "test inventory"
      debug:
       msg: "instance ID : {{item.public_ip_address}}"
      with_items: "{{ec2_test.instances}}" 

    - name: "Add build hosts to inventory"
      add_host:
        name: "{{item.public_ip_address}}"
        ansible_ssh_host: "{{item.public_ip_address}}"
        ansible_user: "ec2-user"
        ansible_ssh_port: 22
        ansible_ssh_private_key_file: "/var/deployment/local_key"
        groups: 
          - build_instances
        ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
      with_items: "{{ec2_build.instances}}"

    - name: "Add test hosts to inventory"
      add_host:
        name: "{{item.public_ip_address}}"
        ansible_ssh_host: "{{item.public_ip_address}}"
        ansible_user: "ec2-user"
        ansible_ssh_port: 22
        ansible_ssh_private_key_file: "/var/deployment/local_key"
        groups: 
          - test_instances
        ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
      with_items: "{{ec2_test.instances}}"
```

The variables we are using in this ansible code are declared in vars.yml file



[root@ip-172-31-11-50 deployment]# chown -R jenkins. /var/deployment/
[root@ip-172-31-11-50 deployment]# ll
total 16
-rw-r--r-- 1 jenkins jenkins   50 Oct 13 13:13 credential.yml
-r-------- 1 jenkins jenkins 2611 Oct 13 13:15 local_key
-rw-r--r-- 1 jenkins jenkins 4090 Oct 13 13:12 main.yml
-rw-r--r-- 1 jenkins jenkins  189 Oct 13 13:13 vars.yml


http://13.233.118.246:8080/github-webhook/


[root@ip-172-31-5-199 ~]# docker image ls
REPOSITORY                TAG                                        IMAGE ID       CREATED          SIZE
abhiramthejas/flask_app   123a966f225fe300ed770b11b0ef3d3d20a3f471   7b9b9ce0fef3   13 minutes ago   62.8MB
abhiramthejas/flask_app   latest                                     7b9b9ce0fef3   13 minutes ago   62.8MB
abhiramthejas/flask_app   9d3c8ef568e8a60ccfbdd0a083f95b458942ace8   d3c3096fed73   24 minutes ago   62.8MB
abhiramthejas/flask_app   4928ce623abf70905ab087060cc56c2d5c2dcdec   68a7df31e2d3   42 minutes ago   62.8MB
alpine                    3.8                                        c8bccc0af957   2 years ago      4.41MB
