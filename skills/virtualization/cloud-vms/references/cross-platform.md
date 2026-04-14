# Cloud VMs Cross-Platform CLI Mapping

Operation-to-CLI mapping across AWS EC2, Azure VMs, and Google Compute Engine.

## Instance Lifecycle

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **Create** | `aws ec2 run-instances --image-id ami-xxx --instance-type t3.medium` | `az vm create --image Ubuntu2204 --size Standard_D4s_v5` | `gcloud compute instances create --machine-type=n2-standard-4 --image-family=debian-12` |
| **List** | `aws ec2 describe-instances --output table` | `az vm list --output table` | `gcloud compute instances list` |
| **Start** | `aws ec2 start-instances --instance-ids i-xxx` | `az vm start --name myVM --resource-group myRG` | `gcloud compute instances start my-instance --zone=zone` |
| **Stop (deallocate)** | `aws ec2 stop-instances --instance-ids i-xxx` | `az vm deallocate --name myVM --resource-group myRG` | `gcloud compute instances stop my-instance --zone=zone` |
| **Restart** | `aws ec2 reboot-instances --instance-ids i-xxx` | `az vm restart --name myVM --resource-group myRG` | `gcloud compute instances reset my-instance --zone=zone` |
| **Delete** | `aws ec2 terminate-instances --instance-ids i-xxx` | `az vm delete --name myVM --resource-group myRG --yes` | `gcloud compute instances delete my-instance --zone=zone --quiet` |
| **Resize** | `aws ec2 modify-instance-attribute --instance-type m5.xlarge` (stopped) | `az vm resize --size Standard_E8s_v5` | `gcloud compute instances set-machine-type --machine-type=n2-highmem-8` (stopped) |
| **Show details** | `aws ec2 describe-instances --instance-ids i-xxx` | `az vm show --name myVM --resource-group myRG` | `gcloud compute instances describe my-instance --zone=zone` |

## Remote Access

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **SSH** | `aws ssm start-session --target i-xxx` | `az ssh vm --name myVM --resource-group myRG` | `gcloud compute ssh my-instance --zone=zone` |
| **SSH (no public IP)** | SSM Session Manager (port 22 not needed) | Bastion / Serial Console | `gcloud compute ssh --tunnel-through-iap` |
| **Run remote script** | `aws ssm send-command --document-name AWS-RunShellScript` | `az vm run-command invoke --command-id RunShellScript` | `gcloud compute ssh --command="bash script.sh"` |
| **Console log** | `aws ec2 get-console-output --instance-id i-xxx` | `az vm boot-diagnostics get-boot-log --name myVM` | `gcloud compute instances get-serial-port-output` |

## Storage

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **Create disk** | `aws ec2 create-volume --size 100 --volume-type gp3` | `az disk create --size-gb 100 --sku Premium_LRS` | `gcloud compute disks create --size=100GB --type=pd-ssd` |
| **Attach disk** | `aws ec2 attach-volume --device /dev/xvdf` | `az vm disk attach --name myDisk` | `gcloud compute instances attach-disk --disk=myDisk` |
| **Detach disk** | `aws ec2 detach-volume --volume-id vol-xxx` | `az vm disk detach --name myDisk` | `gcloud compute instances detach-disk --disk=myDisk` |
| **Resize disk** | `aws ec2 modify-volume --size 200` (online) | `az disk update --size-gb 200` (online) | `gcloud compute disks resize --size=200GB` (online) |
| **Create snapshot** | `aws ec2 create-snapshot --volume-id vol-xxx` | `az snapshot create --source <disk-id>` | `gcloud compute disks snapshot myDisk --snapshot-names=snap` |
| **List snapshots** | `aws ec2 describe-snapshots --owner-ids self` | `az snapshot list --resource-group myRG` | `gcloud compute snapshots list` |

## Images

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **List images** | `aws ec2 describe-images --owners amazon` | `az vm image list --publisher Canonical` | `gcloud compute images list --project=ubuntu-os-cloud` |
| **Create image** | `aws ec2 create-image --instance-id i-xxx` | `az image create --source myVM` | `gcloud compute images create --source-disk=myDisk` |
| **Copy image** | `aws ec2 copy-image --source-region us-east-1` | Image Gallery replication | N/A (images are global) |

## Networking

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **Create firewall rule** | `aws ec2 authorize-security-group-ingress --group-id sg-xxx` | `az network nsg rule create --nsg-name myNSG` | `gcloud compute firewall-rules create --rules=tcp:22` |
| **List firewall rules** | `aws ec2 describe-security-groups` | `az network nsg rule list --nsg-name myNSG` | `gcloud compute firewall-rules list` |
| **Static public IP** | `aws ec2 allocate-address --domain vpc` | `az network public-ip create --sku Standard` | `gcloud compute addresses create --region=region` |
| **Associate IP** | `aws ec2 associate-address --instance-id i-xxx` | Assigned at NIC creation or update | `--address=my-ip` at instance creation |

## Monitoring

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **CPU metrics** | `aws cloudwatch get-metric-statistics --metric CPUUtilization` | `az monitor metrics list --metric "Percentage CPU"` | Cloud Monitoring / Metrics Explorer |
| **Status checks** | `aws ec2 describe-instance-status` | `az vm get-instance-view` | `gcloud compute instances describe --format=value(status)` |
| **Activity logs** | CloudTrail | Activity Log | Cloud Audit Logs |

## Auto-Scaling

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **Create template** | `aws ec2 create-launch-template` | VMSS model / ARM template | `gcloud compute instance-templates create` |
| **Create scale group** | `aws autoscaling create-auto-scaling-group` | `az vmss create` | `gcloud compute instance-groups managed create` |
| **Scale manually** | `aws autoscaling update-auto-scaling-group --desired-capacity N` | `az vmss scale --new-capacity N` | `gcloud compute instance-groups managed resize --size=N` |

## Tags and Labels

| Operation | AWS CLI | Azure CLI | GCP CLI |
|-----------|---------|-----------|---------|
| **Tag at creation** | `--tag-specifications 'ResourceType=instance,Tags=[{Key=Env,Value=prod}]'` | `--tags env=production app=web` | `--labels=env=production,app=web` |
| **Add tag** | `aws ec2 create-tags --resources i-xxx --tags Key=Env,Value=prod` | `az resource tag --tags env=prod` | `gcloud compute instances add-labels --labels=env=prod` |
| **Remove tag** | `aws ec2 delete-tags --resources i-xxx --tags Key=Env` | `az resource tag --tags` (replaces all) | `gcloud compute instances remove-labels --labels=env` |
| **Filter by tag** | `--filters "Name=tag:Env,Values=prod"` | `--query "[?tags.env=='prod']"` | `--filter="labels.env=prod"` |

## Instance Metadata (from inside the VM)

| Cloud | Command |
|-------|---------|
| AWS (IMDSv2) | `TOKEN=$(curl -sX PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" http://169.254.169.254/latest/api/token) && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id` |
| Azure | `curl -s -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2023-07-01"` |
| GCP | `curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name` |

## Key Behavioral Differences

| Behavior | AWS | Azure | GCP |
|----------|-----|-------|-----|
| **Stop = deallocate?** | Yes (always) | No -- must explicitly `deallocate` | Yes (always) |
| **Delete removes disks?** | Root: if `DeleteOnTermination=true` | No (disks persist by default) | Boot: yes by default; data: no |
| **Delete removes public IP?** | Yes (auto-assigned); No (EIP) | No (public IP is separate resource) | Yes (ephemeral); No (static) |
| **Resize requires stop?** | Yes | Sometimes (same-family may be live) | Yes |
| **Default outbound internet** | Via IGW if subnet has route | Via Azure default outbound | Via Cloud NAT or external IP |
| **VPC/VNet scope** | Regional | Regional | Global |
| **Firewall statefulness** | Stateful (SGs) | Stateful (NSGs) | Stateful |
