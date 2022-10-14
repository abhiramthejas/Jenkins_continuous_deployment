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

After accessing the jenkins server run the commands to install the jenkin

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

To install git in the server jenkins please run

```
yum install git -y
```

Then we need to install Ansible and Pyhton module boto to connect ansible with AWS infra in the jenkin server 

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

The variables we are using in this ansible code are declared in vars.yml and credential.yml file

After getting the inventory details from the AWS we can configure our playbook for build server

```
- name: "Building docker image from git on build server"
  hosts: build_instances
  become: true
  vars_files: 
    - vars.yml
    - credential.yml
  tasks:
  

    - name: "Package install"
      yum:
         name: "{{ packages }}"
         state: present
          

    - name: "User add to docker group"
      user:
        name: "ec2-user"
        groups: "docker"
        append: true

    - name: "pip module for docker"
      pip:
        name: docker-py

    - name: "Service start"
      service:
         name: "{{ item }}"
         state: started
         enabled: true
      with_items: "{{ service }}"

    - name: "Git clone"
      git:
        repo: "{{ project_repo }}"
        dest: "{{clone_dir}}"
      register: clone_status

    - name: "Docker hub login"
      when: clone_status.changed == true
      docker_login:
        username: "{{ username }}"
        password: "{{ password }}"
        state: present

    - name: "Docker image create"
      when: clone_status.changed == true
      docker_image:
        name: "{{ image_name }}"
        tag: "{{ item }}"
        force_tag: true
        force_source: true
        source: build
        push: true
        build: 
          path: "{{ clone_dir }}"
          pull: true
      with_items:
        - "{{ clone_status.after }}"
        - latest


    - name: "Docker hub logout"
      when: clone_status.changed == true
      docker_login:
        username: "{{ username }}"
        password: "{{ password }}"
        state: absent
```

The test server configuration of the ansible is 


```
- name: "Running image on test server"
  hosts: test_instances
  become: true
  vars_files: 
    - vars.yml
    - credential.yml
  tasks:

    - name: "Package install"
      yum:
         name: "{{ packages }}"
         state: present
          

    - name: "User add to docker group"
      user:
        name: "ec2-user"
        groups: "docker"
        append: true

    - name: "pip module for docker"
      pip:
        name: docker-py

    - name: "Service start"
      service:
         name: "{{ item }}"
         state: started
         enabled: true
      with_items: "{{ service }}"


    - name: "Docker image pull"
      docker_image:
         name: "{{ image_name }}"
         source: pull
         force_source: true
      register: image_status

    - name: "Docker container run"
      docker_container:
          name: flaskapp
          image: "{{ image_name }}:latest"
          recreate: true
          pull: true
          ports:
            - "80:80"
 ```
 
 After completing the ansible code for test and build server we can continue with our jenkins configuration
 
 Login to the jenkins server using the port 8080
 
 ![jenkins initial login ](https://user-images.githubusercontent.com/17767960/195761382-009b458d-9764-4246-83ba-7e2afda91ef1.jpg)


initial jenkins login password will be in the location 

/var/lib/jenkins/secrets/initialAdminPassword

just cat the file and you will get the key to login to jenkins

After login please select the option continue with plugin installation to install the inital recommended plugins for the jenkins


![jenkins inital plugin install](https://user-images.githubusercontent.com/17767960/195761557-d71971dd-8f8f-421d-ad84-fdd6f34cbc25.jpg)

After completing the plugin install and settting the newadmin credentials, login to the server using the new password


![jenkins login page](https://user-images.githubusercontent.com/17767960/195761780-6c15842a-5757-4498-8aa9-b171e40172a7.jpg)


After completing the initial setting of the jenkins we can install the Ansible plugin in jenkins to manage ansible with jenkin

Choose option Manage jenkins > Manage plugin > Search for Ansible > Select Ansible > Install without restart

![search ansible ](https://user-images.githubusercontent.com/17767960/195762063-2df0392b-6ded-4c96-9d97-1c60b56ade75.jpg)

After plugin install please choose option restart jenkin and the jenkin service will restart


![restart jenkin](https://user-images.githubusercontent.com/17767960/195762403-6a07b3d3-cfba-440a-8a51-d6e5501b21a6.jpg)

![jenkin restart](https://user-images.githubusercontent.com/17767960/195762429-1f5dd083-b5a8-46fb-8603-0d37df67d22d.jpg)


It will take some time to complete the process.

Next we need to configure ansible path with jenkin, to do that please choose the option Global configuration and choose Ansible

![ansible path set](https://user-images.githubusercontent.com/17767960/195762959-4249ef72-50ab-4702-b041-cc0f0e5d4bf2.png)

you can get the ansible path by running comment 

```
[ec2-user@ip-172-31-11-50 ~]$ which ansible
/usr/local/bin/ansible
```
Here our location will be /usr/local/bin/

After setting the ansible path we can configure our project by choosing the option New item from the jenkin dashboard and provide a name for your project and choose free style project


![add new item](https://user-images.githubusercontent.com/17767960/195763470-cf0aea20-08cb-4888-8bd9-e17fba21a686.png)

From the next window provide a desription for your project in the description box 

Choose source code management as Git
Provide your git repository URL
here I am using https://github.com/abhiramthejas/flask-app

Also make sure to select your branch

![source code managemnt build setup](https://user-images.githubusercontent.com/17767960/195764041-0d8c8e2a-8dcb-4380-9f76-6ad946090d00.png)


Then from the build setup choose the Add build step and choose the option invoke ansible playbook

Provide your ansible playbook path 
Here I am using /var/deployment/main.yml as my path for ansible files

and make sure the ownership of the files are added correctly

```
[root@ip-172-31-11-50 deployment]# chown -R jenkins. /var/deployment/
[root@ip-172-31-11-50 deployment]# ll
total 16
-rw-r--r-- 1 jenkins jenkins   50 Oct 13 13:13 credential.yml
-r-------- 1 jenkins jenkins 2611 Oct 13 13:15 local_key
-rw-r--r-- 1 jenkins jenkins 4090 Oct 13 13:12 main.yml
-rw-r--r-- 1 jenkins jenkins  189 Oct 13 13:13 vars.yml
```

As we are using dynamic inventory here in the playbook we can choose the option do not specify inventory else you need to specify your ansible host invetoy path in the Inventory section

![build steps invoke ansible](https://user-images.githubusercontent.com/17767960/195764627-6c13d146-2565-42af-a1db-7c7066808969.png)

If you encrypted the ansible file using ansible-vault please make sure to add your vault credentials in jenkins

![credenial add vault jenkins](https://user-images.githubusercontent.com/17767960/195764734-d70fadce-47c5-46f9-97c1-9573d7064b80.png)

![vault credential add](https://user-images.githubusercontent.com/17767960/195764795-55757122-ec12-403b-ad90-f06ac2b285ee.png)

Then we can save the project and try building it manually to test our project

To run the project click on build now 

![build 1st jenkins](https://user-images.githubusercontent.com/17767960/195765102-64351b67-f9d3-4232-b052-37693729d2ae.png)

And from the build history section you can get the console output of the build

![play build success 1](https://user-images.githubusercontent.com/17767960/195765254-ff83e174-4c2a-4850-83f8-365b65a11d3b.png)

And we can verify the build by accessing or app via browser and we can aslo check in our docker hub for the image 

![version1 webpage](https://user-images.githubusercontent.com/17767960/195765405-61f315a0-c68a-4d3f-b8ee-0f9a40506c46.png)

![docker hub image](https://user-images.githubusercontent.com/17767960/195765562-f7890606-1a84-4a78-978f-29ec6c906c08.png)

![dockerhub image list](https://user-images.githubusercontent.com/17767960/195765599-6fce0a31-e967-4d04-938b-1096e610ce08.png)

Then we can try changing our app and test if new change also works for the build by commiting the new change to the git repository

![version 2 github commit](https://user-images.githubusercontent.com/17767960/195765820-85b6c5f0-7c7d-4333-8111-0d992aa24065.png)


Then try build again in jenkins manually to test the change

![build 2nd commit test jenkins](https://user-images.githubusercontent.com/17767960/195765933-d5f7a264-0a02-40d1-aca1-17fad08ac1f9.png)

![version 2 playbook success](https://user-images.githubusercontent.com/17767960/195766041-b71e49dd-086a-4a2d-91af-a9bb21860c01.png)

If everything goes as we planed we can see our app changed when we access it via webpage and new image added in the dockerhub


![version 2 webpage](https://user-images.githubusercontent.com/17767960/195766129-69fee859-3a59-49be-863e-8f7a9ebf39cb.png)

![version 2 docker hub](https://user-images.githubusercontent.com/17767960/195766234-3615b587-f519-43f2-bcbd-b79e2d21239c.png)

Next we need to automate the git change to build the image and run the docker image image in test server

For that we need to set the wehook in the git repository and need to change the jenkins configuration to make the build when webhook receive

To change the settings in git, please login to your github repository and choose your git and select the settings of the repository and choose option webhook

![webhook github](https://user-images.githubusercontent.com/17767960/195766591-93fb1104-4ea2-428e-9611-06789571dd34.png)


Add new webhook and provide your server details in payload URL http://IP:8080/github-webhook/ (here im using http://13.233.118.246:8080/github-webhook/) and make sure it is active and choose Add webhook

![add webhook in github](https://user-images.githubusercontent.com/17767960/195766902-dd814b8a-a330-4b57-a4a4-989aaabfa720.png)


After seting the wehook in github we need to configure jenkins 

Choose your project from the jenkins and select the option configure and select build trigger as Github hook trigger and save 


![github hook trigger in jenkins](https://user-images.githubusercontent.com/17767960/195767457-40dfb25d-3a31-417b-a640-ca3e4ec6c9f1.png)

Now if development team commit a change in the git it will automatically build the app and run it in the test server!!

![version 3 commited](https://user-images.githubusercontent.com/17767960/195767704-b9d8434e-15f8-44eb-9767-8c31d26d8564.png)
![version 3 play success](https://user-images.githubusercontent.com/17767960/195767750-2e3b0823-dd50-47dd-8b32-67d3b6dcbdc9.png)
![version 3 webpage](https://user-images.githubusercontent.com/17767960/195767769-3aaf86f8-d2a4-4171-8d7b-53be7e93379a.png)


