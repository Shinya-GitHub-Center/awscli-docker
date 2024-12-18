# [Wiki Site : Let's study a basic IaaS skill by installing commonly used software](https://github.com/Shinya-GitHub-Center/awscli-docker/wiki)

## About
- AWS management tool - AWS CLI - docker container version
- Including simple WordPress deployment test script. If you want to try this test deployment over aws server, login with IAM user who was attached AdministratorAccess policy, then `bash ./infra-setup.sh` @workdir directory.

## Basic use
1. Download the source of the latest commit or latest release of this repository, then unzip and rename the root folder's name to your favorite one.
2. Rename the file name `.env.sample` to `.env`
3. Set your own access key into .env file (this credential key can be generated after you have created an IAM user)
4. On your linux environment, go to the directory where this project's `docker-compose.yml` file exists, then run the following command:
```
docker compose up -d
```
5. Enter the docker container, the command for instance:
```
docker exec -it <created docker container name> bash
```
6. That's it! You can now use `aws` command to manage your aws account under the authority of logged-in IAM user.

## To switch role
1. If you intend to use cross account by switching role to another account, please fill out the variables in `./aws-cli/workdir/vars-switchrole.txt`
2. Execute "switch-role" shell script in the workdir directory in order to switch role to another account:  
(Do not use "bash" command when execute script file, since this can not transfer environment variables into your docker machine, I don't know why...)
```
source ~/workdir/switch-role.sh
```
3. When you want to switch back to the original IAM user, just `exit` your docker container and re-enter the container:
```
exit
docker exec -it <created docker container name> bash
```
4. If the switching-roll session is expired, please `exit` the container and re-enter the container, followed by the execution of "switch-role" shell script in order to re-issue credentials

## Access to EC2 instance using Session Manager
1. Make sure if your ec2 instance has SSM Agent installed and being active
2. Create a new IAM Role which is including the aws managed policy called `AmazonSSMManagedInstanceCore`
3. Assign the created role to the destination ec2 instance
4. Run the command
```
aws ssm start-session --target <instance-id>
```
5. To finish the session, just `exit`

## Access to EC2 instance using traditional ssh but over Session Manager
1. Locate your EC2 instance's keyfile into `./aws-cli/.ssh/keyfiles/` and modify `./aws-cli/.ssh/config` file
2. Path to the key files has to be full path. HostName has to be the instance id. It is not necessary to change anything at ProxyCommand section
3. Change the permission with the key (from the docker container)
```
chmod 600 ~/.ssh/keyfiles/veryhappy.pem
```
4. Run the command with Host attribute - which is written in the config file
```
ssh myomgweb
```

## Access to EC2 instance using EC2 Instance Connect
1. Please make sure if your instance's operation system is supported, along with available regions from [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html#ic-limitations)
2. Run the command
```
mssh ec2-user@<instance-id>
or
mssh ubuntu@<instance-id>
```
3. This EC2 Instance Connect over local aws-cli command line does not require key pair generation beforehand, but requires public IP address (can not connect to private subnet)

## Please
* Do not delete `./.env` file after copied your credential keys, and keep this file secret! Do not upload or share to any public places
* Do not delete any key files inside `./aws-cli/.ssh/keyfiles` folder. They are not supposed to be issued again due to the cloud vendor's strict rules, and keep the keyfiles secret - do not upload or share to any public places
* If you want to use another UID & GID inside the docker container, in order to match your host's UID & GID, please change the Dockerfile's `ARG UID=1000` & `ARG GID=1000` to your desired number
