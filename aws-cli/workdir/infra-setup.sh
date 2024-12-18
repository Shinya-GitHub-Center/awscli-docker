#!/bin/bash

set -eu

# This script will create 1 VPC on a 2 regions (single region is not allowed for managed RDS),
# 2 Public Subnets and 2 Private Subnets over 2 availability zones,
# 1 Internet Gateway, 2 Route Tables associated with public and private subnet (except main RT),
# 1 default SG, 1 public (SSH/HTTP/HTTPS) SG, and 1 private SG (MYSQL)
# 1 Network ACL, no pair key generated (only use EC2 Instance Connect),
# 1 EC2 instance creating at public subnet, and 1 RDS (MariaDB) at private subnet

##############################
# Variables
##############################

# for VPC
VPC_CIDR="10.66.0.0/16"
PRJ_NAME="wtfblog"
PUBLIC_SUBNET="10.66.10.0/24"
MAIN_PRIVATE_SUBNET="10.66.20.0/24"
SUB_PRIVATE_SUBNET="10.66.25.0/24"
SSH_CIDR="0.0.0.0/0"
REGION="us-east-1"
MAIN_AZ="a"
SUB_AZ="b"

# for EC2 instance
# Use Amazon Linux 2023 both for app and db servers
AMI_ID="ami-0453ec754f44f9a4a"
INST_TYPE="t2.micro"
PVTIP_ADDR_INSTAPP="10.66.10.83"
# The path of web server setting script
USER_DATA_INSTAPP="./wp-init.sh"

# for database subnet group
DB_SUBNET_GPNAME="wtfblog-pvtsub"
DB_SUBNET_DESC="2 different AZ combo for wtfblog database"

# for db instance
DB_IDENTITY="wtfblog-db-server"
DB_CLASS="db.t4g.micro"
ENGINE="mariadb"
ENGINE_VER="10.11.9"
DB_NAME="wordpressdb"
MASTER_NAME="root"
MASTER_PASS="root0000"
STG_TYPE="gp2"
ALLOW_STORAGE="20"
MAX_STG="100"
NWKTYPE="IPV4"

##############################
# Create VPC and more
##############################

echo "Creating VPC and more..."
# Create VPC and return VPC_ID
VPC_ID=$(aws ec2 create-vpc --cidr-block "${VPC_CIDR}" --query Vpc.VpcId --output text)
# Attach a tag to the created VPC
aws ec2 create-tags --resources "${VPC_ID}" --tags Key=Name,Value="${PRJ_NAME}-vpc"

# Create Public Subnet and return PUBLIC_SUBNET_ID
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "${PUBLIC_SUBNET}" --availability-zone "${REGION}${MAIN_AZ}" --query Subnet.SubnetId --output text)
# Attach a tag to the created Public Subnet
aws ec2 create-tags --resources "${PUBLIC_SUBNET_ID}" --tags Key=Name,Value="${PRJ_NAME}-subnet-public1-${REGION}${MAIN_AZ}"

# Create Main Private Subnet and return PRIVATE_SUBNET_ID
MAIN_PRIVATE_SUBNET_ID=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "${MAIN_PRIVATE_SUBNET}" --availability-zone "${REGION}${MAIN_AZ}" --query Subnet.SubnetId --output text)
# Attach a tag to the created Private Subnet
aws ec2 create-tags --resources "${MAIN_PRIVATE_SUBNET_ID}" --tags Key=Name,Value="${PRJ_NAME}-subnet-private1-${REGION}${MAIN_AZ}"

# Create Sub Private Subnet and return PRIVATE_SUBNET_ID
SUB_PRIVATE_SUBNET_ID=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "${SUB_PRIVATE_SUBNET}" --availability-zone "${REGION}${SUB_AZ}" --query Subnet.SubnetId --output text)
# Attach a tag to the created Private Subnet
aws ec2 create-tags --resources "${SUB_PRIVATE_SUBNET_ID}" --tags Key=Name,Value="${PRJ_NAME}-subnet-private2-${REGION}${SUB_AZ}"

# Create Internet Gateway and return IGW_ID
IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
# Attach a tag to the created Internet Gateway
aws ec2 create-tags --resources "${IGW_ID}" --tags Key=Name,Value="${PRJ_NAME}-igw"
# Connect Internet Gateway to the created VPC
aws ec2 attach-internet-gateway --vpc-id "${VPC_ID}" --internet-gateway-id "${IGW_ID}"

# Create Route Table for public subnet
PUBLIC_RTB_ID=$(aws ec2 create-route-table --vpc-id "${VPC_ID}" --query RouteTable.RouteTableId --output text)
# Attach a tag to the created Route Table for public subnet
aws ec2 create-tags --resources "${PUBLIC_RTB_ID}" --tags Key=Name,Value="${PRJ_NAME}-rtb-public"
# Associate the created Route Table with public subnet
RTBASSOC_PUB_ID=$(aws ec2 associate-route-table --subnet-id "${PUBLIC_SUBNET_ID}" --route-table-id "${PUBLIC_RTB_ID}" --query AssociationId --output text)

# Create Route Table for private subnet
PRIVATE_RTB_ID=$(aws ec2 create-route-table --vpc-id "${VPC_ID}" --query RouteTable.RouteTableId --output text)
# Attach a tag to the created Route Table for private subnet
aws ec2 create-tags --resources "${PRIVATE_RTB_ID}" --tags Key=Name,Value="${PRJ_NAME}-rtb-private"
# Associate the created Route Table with 2 different private subnets
RTBASSOC_MAINPRV_ID=$(aws ec2 associate-route-table --subnet-id "${MAIN_PRIVATE_SUBNET_ID}" --route-table-id "${PRIVATE_RTB_ID}" --query AssociationId --output text)
RTBASSOC_SUBPRV_ID=$(aws ec2 associate-route-table --subnet-id "${SUB_PRIVATE_SUBNET_ID}" --route-table-id "${PRIVATE_RTB_ID}" --query AssociationId --output text)

# Create a new Security Group intended for attaching to the web server EC2 instance
APP_SG_ID=$(aws ec2 create-security-group --group-name "app-security" --description "Only allowed incoming access at SSH, HTTP, and HTTPS" --vpc-id "${VPC_ID}" --query GroupId --output text)
DB_SG_ID=$(aws ec2 create-security-group --group-name "db-security" --description "Only allowed db access from app-security" --vpc-id "${VPC_ID}" --query GroupId --output text)
# Add custom inbound rules
SGR_SSH_BL=$(aws ec2 authorize-security-group-ingress --group-id "${APP_SG_ID}" --protocol tcp --port 22 --cidr "${SSH_CIDR}" --query Return --output text)
SGR_HTTP_BL=$(aws ec2 authorize-security-group-ingress --group-id "${APP_SG_ID}" --protocol tcp --port 80 --cidr 0.0.0.0/0 --query Return --output text)
SGR_HTTPS_BL=$(aws ec2 authorize-security-group-ingress --group-id "${APP_SG_ID}" --protocol tcp --port 443 --cidr 0.0.0.0/0 --query Return --output text)
SGR_MYSQL_BL=$(aws ec2 authorize-security-group-ingress --group-id "${DB_SG_ID}" --protocol tcp --port 3306 --source-group "${APP_SG_ID}" --query Return --output text)

# Add Internet Gateway Route for public subnet route table
ROUTE_IGW_BL=$(aws ec2 create-route --route-table-id "${PUBLIC_RTB_ID}" --destination-cidr-block 0.0.0.0/0 --gateway-id "${IGW_ID}" --query Return --output text)

# So that the web server instance can automatically receive a dynamic public IP address upon launching
aws ec2 modify-subnet-attribute --subnet-id "${PUBLIC_SUBNET_ID}" --map-public-ip-on-launch

# Enable DNS hostname and DNS resolution for the created VPC
aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_ID}" --enable-dns-hostnames '{"Value":true}'
aws ec2 modify-vpc-attribute --region "${REGION}" --vpc-id "${VPC_ID}" --enable-dns-support '{"Value":true}'

##############################
# Create EC2 instance for web/app server
##############################

INSTAPP_ID=$(aws ec2 run-instances \
    --region "${REGION}" \
    --image-id "${AMI_ID}" --count 1 \
    --instance-type "${INST_TYPE}" \
    --subnet-id "${PUBLIC_SUBNET_ID}" --private-ip-address "${PVTIP_ADDR_INSTAPP}" \
    --security-group-ids "${APP_SG_ID}" \
    --user-data file://"${USER_DATA_INSTAPP}" \
    --private-dns-name-options "EnableResourceNameDnsARecord=true" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value='${PRJ_NAME}-app-server'}]" \
    --query Instances[0].InstanceId --output text)

# Return to prompt only after app-server instance successfully passed checks (async)
{
    echo "Waiting for ${INSTAPP_ID} to be passed checks..."
    aws ec2 wait instance-status-ok --instance-ids "${INSTAPP_ID}"
    echo "EC2 instance running successfully!"
} &
EC2_WAIT_PID=$!

##############################
# RDS database setting up
##############################

# Create db subnet group
GPNAME_RTN=$(aws rds create-db-subnet-group \
    --db-subnet-group-name "${DB_SUBNET_GPNAME}" \
    --db-subnet-group-description "${DB_SUBNET_DESC}" \
    --subnet-ids "${MAIN_PRIVATE_SUBNET_ID}" "${SUB_PRIVATE_SUBNET_ID}" \
    --query DBSubnetGroup.DBSubnetGroupName --output text)

# Create db instance
DB_IDENTITY_RTN=$(aws rds create-db-instance \
    --db-instance-identifier "${DB_IDENTITY}" \
    --db-instance-class "${DB_CLASS}" \
    --engine "${ENGINE}" \
    --engine-version "${ENGINE_VER}" \
    --db-name "${DB_NAME}" \
    --no-manage-master-user-password \
    --master-username "${MASTER_NAME}" \
    --master-user-password "${MASTER_PASS}" \
    --storage-type "${STG_TYPE}" \
    --max-allocated-storage "${MAX_STG}" \
    --allocated-storage "${ALLOW_STORAGE}" \
    --network-type "${NWKTYPE}" \
    --no-multi-az \
    --no-publicly-accessible \
    --vpc-security-group-ids "${DB_SG_ID}" \
    --db-subnet-group-name "${GPNAME_RTN}" \
    --availability-zone "${REGION}${MAIN_AZ}" \
    --no-copy-tags-to-snapshot \
    --backup-retention-period 0 \
    --storage-encrypted \
    --no-enable-iam-database-authentication \
    --no-deletion-protection \
    --auto-minor-version-upgrade \
    --query DBInstance.DBInstanceIdentifier --output text)

# Return to prompt only after db-server instance successfully available (async)
{
    echo "Waiting for ${DB_IDENTITY_RTN} to be available..."
    aws rds wait db-instance-available --db-instance-identifier "${DB_IDENTITY_RTN}"
    echo "RDS instance running successfully!"
} &
RDS_WAIT_PID=$!

##############################
# Wait until both EC2 and RDS instances available
##############################

wait $EC2_WAIT_PID
wait $RDS_WAIT_PID

##############################
# Generation of the final messages
##############################

# Extract public IP address from deployed EC2 instance
EC2_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "${INSTAPP_ID}" \
    --query Reservations[0].Instances[0].PublicIpAddress \
    --output text)

# Extract RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "${DB_IDENTITY_RTN}" \
    --query DBInstances[0].Endpoint.Address \
    --output text)

echo "All resources have been successfully running!"
echo " - EC2 instance ID: ${INSTAPP_ID}"
echo " - RDS instance identifier: ${DB_IDENTITY_RTN}"
echo "----------------------------------------"
echo "Required info for wp initial setup as follows"
echo "WP access URL: http://${EC2_PUBLIC_IP}"
echo "Database Name: ${DB_NAME}"
echo "Username: ${MASTER_NAME}"
echo "Password: ${MASTER_PASS}"
echo "Database Host: ${RDS_ENDPOINT}"
