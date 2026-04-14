# AWS EC2 CLI Reference

Complete `aws ec2` CLI reference for instance lifecycle, AMIs, EBS, networking, SSM, and monitoring.

---

## Instance Lifecycle

### Create Instance

```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.medium \
  --key-name my-key-pair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0123456789abcdef0 \
  --user-data file://init.sh \
  --iam-instance-profile Name=MyInstanceRole \
  --ebs-optimized \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 30,
        "VolumeType": "gp3",
        "Iops": 3000,
        "Throughput": 125,
        "DeleteOnTermination": true,
        "Encrypted": true
      }
    }
  ]' \
  --tag-specifications \
    'ResourceType=instance,Tags=[{Key=Name,Value=my-server},{Key=Env,Value=prod}]' \
    'ResourceType=volume,Tags=[{Key=Name,Value=my-server-root}]' \
  --metadata-options HttpTokens=required \
  --disable-api-termination \
  --count 1
```

Launch a Spot instance:
```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type c5.xlarge \
  --instance-market-options '{
    "MarketType": "spot",
    "SpotOptions": {
      "MaxPrice": "0.05",
      "SpotInstanceType": "one-time",
      "InstanceInterruptionBehavior": "terminate"
    }
  }' \
  --count 1
```

Key parameters: `--image-id`, `--instance-type`, `--key-name`, `--security-group-ids`, `--subnet-id`, `--user-data`, `--iam-instance-profile`, `--block-device-mappings`, `--tag-specifications`, `--disable-api-termination`, `--metadata-options`, `--placement`, `--launch-template`, `--count`.

### List Instances

```bash
# All running instances with name, ID, type, IP
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Filter by tag and state
aws ec2 describe-instances \
  --filters \
    "Name=tag:Env,Values=prod" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text

# All instances: name, ID, type, state, IP
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,InstanceType,State.Name,PublicIpAddress]' \
  --output table
```

Common `--filters`: `instance-state-name`, `instance-type`, `tag:<key>`, `vpc-id`, `subnet-id`, `image-id`, `key-name`, `security-group-id`.

### Start / Stop / Reboot / Terminate

```bash
aws ec2 start-instances --instance-ids i-0abc i-0def
aws ec2 stop-instances --instance-ids i-0abc
aws ec2 stop-instances --instance-ids i-0abc --hibernate
aws ec2 stop-instances --instance-ids i-0abc --force
aws ec2 reboot-instances --instance-ids i-0abc
aws ec2 terminate-instances --instance-ids i-0abc i-0def

# Wait for state transitions
aws ec2 wait instance-running    --instance-ids i-0abc
aws ec2 wait instance-stopped    --instance-ids i-0abc
aws ec2 wait instance-terminated --instance-ids i-0abc
```

### Resize (Change Instance Type)

Instance must be stopped:
```bash
aws ec2 stop-instances --instance-ids i-0abc
aws ec2 wait instance-stopped --instance-ids i-0abc
aws ec2 modify-instance-attribute \
  --instance-id i-0abc \
  --instance-type '{"Value": "m5.xlarge"}'
aws ec2 start-instances --instance-ids i-0abc
```

### Termination Protection

```bash
aws ec2 modify-instance-attribute \
  --instance-id i-0abc \
  --disable-api-termination '{"Value": true}'
```

---

## AMIs (Images)

### Find AMIs

```bash
# Latest Amazon Linux 2 (x86_64)
aws ec2 describe-images \
  --owners amazon \
  --filters \
    "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
    "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name,CreationDate]' \
  --output text

# Latest Ubuntu 22.04 (Canonical owner: 099720109477)
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name]' \
  --output text
```

### Create AMI from Instance

```bash
aws ec2 create-image \
  --instance-id i-0abc \
  --name "my-server-$(date +%Y%m%d)" \
  --description "Pre-upgrade snapshot" \
  --no-reboot

aws ec2 wait image-available --image-ids ami-xxxxxxxxx
```

### Copy AMI Cross-Region

```bash
aws ec2 copy-image \
  --source-region us-east-1 \
  --source-image-id ami-0abc \
  --name "my-server-us-west-2" \
  --region us-west-2
```

---

## Storage (EBS)

### Create / Attach / Detach / Delete Volumes

```bash
# Create gp3 volume
aws ec2 create-volume \
  --availability-zone us-east-1a \
  --size 100 \
  --volume-type gp3 \
  --iops 3000 \
  --throughput 125 \
  --encrypted \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=data-disk}]'

aws ec2 wait volume-available --volume-ids vol-0abc

# Attach
aws ec2 attach-volume \
  --volume-id vol-0abc \
  --instance-id i-0abc \
  --device /dev/xvdf

# Detach (unmount in OS first)
aws ec2 detach-volume --volume-id vol-0abc

# Delete (must be detached)
aws ec2 delete-volume --volume-id vol-0abc
```

### Snapshots

```bash
aws ec2 create-snapshot \
  --volume-id vol-0abc \
  --description "Pre-upgrade backup" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=pre-upgrade}]'

aws ec2 wait snapshot-completed --snapshot-ids snap-0abc

aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=status,Values=completed" \
  --query 'Snapshots[].[SnapshotId,VolumeId,StartTime,Description]' \
  --output table
```

### Modify Volume (Online)

```bash
# Upgrade gp2 to gp3
aws ec2 modify-volume \
  --volume-id vol-0abc \
  --volume-type gp3 \
  --iops 4000 \
  --throughput 250

# Expand size (no downtime)
aws ec2 modify-volume --volume-id vol-0abc --size 200

# Check progress
aws ec2 describe-volumes-modifications \
  --volume-ids vol-0abc \
  --query 'VolumesModifications[].[VolumeId,ModificationState,Progress]' \
  --output table
```

---

## Networking

### VPCs and Subnets

```bash
aws ec2 describe-vpcs \
  --query 'Vpcs[].[VpcId,CidrBlock,IsDefault,Tags[?Key==`Name`].Value|[0]]' \
  --output table

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0abc" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

### Security Groups

```bash
# Allow SSH from CIDR
aws ec2 authorize-security-group-ingress \
  --group-id sg-0abc --protocol tcp --port 22 --cidr 10.0.0.0/8

# Allow HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id sg-0abc \
  --ip-permissions '[
    {
      "IpProtocol": "tcp", "FromPort": 443, "ToPort": 443,
      "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
      "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
    }
  ]'

# Allow from another security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-0abc \
  --ip-permissions '[
    {
      "IpProtocol": "tcp", "FromPort": 8080, "ToPort": 8080,
      "UserIdGroupPairs": [{"GroupId": "sg-0def"}]
    }
  ]'

# Revoke by rule ID
aws ec2 revoke-security-group-ingress \
  --group-id sg-0abc \
  --security-group-rule-ids sgr-0abc
```

### Elastic IPs

```bash
aws ec2 allocate-address --domain vpc
aws ec2 associate-address --instance-id i-0abc --allocation-id eipalloc-0abc
aws ec2 describe-addresses --output table
aws ec2 disassociate-address --association-id eipassoc-0abc
aws ec2 release-address --allocation-id eipalloc-0abc
```

---

## Key Management

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name my-key \
  --key-type ed25519 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-key.pem
chmod 400 ~/.ssh/my-key.pem

# Import existing public key
aws ec2 import-key-pair \
  --key-name my-existing-key \
  --public-key-material fileb://~/.ssh/id_rsa.pub

# List and delete
aws ec2 describe-key-pairs --output table
aws ec2 delete-key-pair --key-name my-key
```

---

## SSM (Systems Manager)

### Interactive Session (No SSH Key or Open Port Required)

```bash
aws ssm start-session --target i-0abc

# Port forwarding
aws ssm start-session \
  --target i-0abc \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3306"],"localPortNumber":["13306"]}'
```

Prerequisites: IAM role with `AmazonSSMManagedInstanceCore`, SSM agent running, Session Manager plugin installed locally.

### Remote Command Execution

```bash
# Run shell commands
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids i-0abc \
  --parameters commands=["uptime","df -h","free -m"]

# Run on tagged instances
aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets 'Key=tag:Env,Values=prod' \
  --parameters commands=["systemctl restart nginx"] \
  --max-concurrency 10 \
  --max-errors 2

# Capture output
COMMAND_ID=$(aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids i-0abc \
  --parameters commands=["hostname"] \
  --query 'Command.CommandId' --output text)

aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id i-0abc \
  --query 'StandardOutputContent' --output text
```

---

## Monitoring

### Instance Status Checks

```bash
aws ec2 describe-instance-status \
  --instance-ids i-0abc \
  --query 'InstanceStatuses[].[InstanceId,InstanceState.Name,SystemStatus.Status,InstanceStatus.Status]' \
  --output table
```

### CloudWatch Metrics

```bash
# CPU utilization (last hour, 5-min intervals)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0abc \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average Maximum \
  --output table
```

Key metrics: `CPUUtilization`, `NetworkIn`, `NetworkOut`, `DiskReadOps`, `DiskWriteOps`, `StatusCheckFailed`, `StatusCheckFailed_System`, `StatusCheckFailed_Instance`.

### Console Output and Screenshot

```bash
aws ec2 get-console-output --instance-id i-0abc --latest --query 'Output' --output text
aws ec2 get-console-screenshot --instance-id i-0abc --query 'ImageData' --output text | base64 -d > screenshot.png
```

---

## Launch Templates

```bash
# Create template
aws ec2 create-launch-template \
  --launch-template-name prod-server-lt \
  --version-description "v1 - initial" \
  --launch-template-data '{
    "ImageId": "ami-0abcdef1234567890",
    "InstanceType": "m5.large",
    "KeyName": "my-key",
    "SecurityGroupIds": ["sg-0abc"],
    "IamInstanceProfile": {"Name": "EC2InstanceRole"},
    "EbsOptimized": true,
    "MetadataOptions": {"HttpTokens": "required"},
    "BlockDeviceMappings": [{
      "DeviceName": "/dev/xvda",
      "Ebs": {"VolumeSize": 30, "VolumeType": "gp3", "Encrypted": true}
    }],
    "TagSpecifications": [{
      "ResourceType": "instance",
      "Tags": [{"Key": "Env", "Value": "prod"}]
    }]
  }'

# Launch from template
aws ec2 run-instances \
  --launch-template LaunchTemplateName=prod-server-lt,Version='$Latest' \
  --instance-type m5.xlarge \
  --count 2
```

---

## Auto Scaling Groups

```bash
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name prod-asg \
  --launch-template LaunchTemplateId=lt-0abc,Version='$Latest' \
  --min-size 2 --max-size 10 --desired-capacity 3 \
  --vpc-zone-identifier "subnet-0abc,subnet-0def" \
  --health-check-type ELB \
  --health-check-grace-period 120

# Scale manually
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name prod-asg \
  --desired-capacity 6

# Inspect
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names prod-asg
```

---

## Useful One-Liners

```bash
# Get instance ID by Name tag
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=my-server" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text

# Terminate all instances with a specific tag
aws ec2 terminate-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Env,Values=test" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' --output text)

# IMDSv2 metadata fetch from inside instance
TOKEN=$(curl -sX PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```
