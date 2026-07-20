# Google Compute Engine CLI Reference

Complete `gcloud compute` CLI reference for instance lifecycle, images, disks, networking, SSH/IAP, and monitoring.

---

## Instance Lifecycle

### Create Instance

```bash
# Full creation with all options
gcloud compute instances create my-instance \
  --project=my-project \
  --zone=us-central1-a \
  --machine-type=n2-standard-4 \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-ssd \
  --boot-disk-device-name=my-instance-boot \
  --network=my-vpc \
  --subnet=my-subnet \
  --private-network-ip=10.0.1.10 \
  --no-address \
  --tags=http-server,https-server,ssh-allowed \
  --metadata=enable-oslogin=true \
  --metadata-from-file=startup-script=startup.sh \
  --service-account=my-sa@my-project.iam.gserviceaccount.com \
  --scopes=cloud-platform \
  --labels=env=production,app=webserver,team=infra \
  --min-cpu-platform="Intel Cascade Lake" \
  --maintenance-policy=MIGRATE

# Instance with external IP
gcloud compute instances create my-public-instance \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --address=my-static-ip
```

### List Instances

```bash
# All instances in project
gcloud compute instances list

# Filter by zone
gcloud compute instances list --filter="zone:us-central1-a"

# Filter by label
gcloud compute instances list --filter="labels.env=production"

# Custom format output
gcloud compute instances list \
  --format="table(name,zone,machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"

# Running instances only
gcloud compute instances list \
  --filter="status=RUNNING" \
  --format="table(name,zone,machineType,status)"
```

### Start / Stop / Reset / Delete

```bash
# Start
gcloud compute instances start my-instance --zone=us-central1-a

# Stop (always deallocates compute)
gcloud compute instances stop my-instance --zone=us-central1-a

# Reset (hard power cycle)
gcloud compute instances reset my-instance --zone=us-central1-a

# Delete
gcloud compute instances delete my-instance --zone=us-central1-a --quiet

# Delete but keep boot disk
gcloud compute instances delete my-instance --zone=us-central1-a --keep-disks=boot

# Bulk stop by label
gcloud compute instances list \
  --filter="labels.env=dev" \
  --format="value(name,zone)" | \
  while read name zone; do
    gcloud compute instances stop "$name" --zone="$zone" --quiet
  done
```

### Change Machine Type (Resize)

```bash
# Must stop first
gcloud compute instances stop my-instance --zone=us-central1-a

gcloud compute instances set-machine-type my-instance \
  --zone=us-central1-a \
  --machine-type=n2-highmem-8

gcloud compute instances start my-instance --zone=us-central1-a
```

### Describe Instance

```bash
# Full JSON
gcloud compute instances describe my-instance \
  --zone=us-central1-a --format=json

# Specific fields
gcloud compute instances describe my-instance \
  --zone=us-central1-a \
  --format="value(status,machineType,networkInterfaces[0].networkIP)"
```

---

## Images

### Public Images

```bash
# List by project
gcloud compute images list --project=debian-cloud
gcloud compute images list --project=ubuntu-os-cloud
gcloud compute images list --project=centos-cloud
gcloud compute images list --project=windows-cloud
gcloud compute images list --project=cos-cloud

# Non-deprecated images only
gcloud compute images list \
  --project=ubuntu-os-cloud \
  --filter="NOT deprecated:*" \
  --format="table(name,family,status)"
```

### Custom Images

```bash
# Create from stopped instance's disk
gcloud compute images create my-custom-image \
  --source-disk=my-instance \
  --source-disk-zone=us-central1-a \
  --family=my-app-base \
  --description="Production base image v1.0" \
  --labels=version=1-0,team=infra

# Create from snapshot
gcloud compute images create my-image-from-snap \
  --source-snapshot=my-snapshot \
  --family=my-app-base

# Deprecate old image
gcloud compute images deprecate my-old-image \
  --state=DEPRECATED \
  --replacement=my-custom-image
```

---

## Disks

### Create and Manage

```bash
# Create persistent disk
gcloud compute disks create my-data-disk \
  --zone=us-central1-a \
  --size=500GB \
  --type=pd-ssd \
  --labels=env=production

# Describe disk
gcloud compute disks describe my-data-disk --zone=us-central1-a

# Resize (online, no downtime)
gcloud compute disks resize my-data-disk \
  --zone=us-central1-a \
  --size=1000GB
```

### Snapshots

```bash
# Create snapshot
gcloud compute disks snapshot my-data-disk \
  --zone=us-central1-a \
  --snapshot-names=my-data-disk-snap-$(date +%Y%m%d) \
  --description="Weekly backup snapshot"

# List snapshots
gcloud compute snapshots list --filter="sourceDisk:my-data-disk"

# Create disk from snapshot
gcloud compute disks create my-restored-disk \
  --source-snapshot=my-data-disk-snap-20240101 \
  --zone=us-central1-a \
  --type=pd-ssd
```

### Attach and Detach

```bash
# Attach (rw for exclusive, ro for shared read-only)
gcloud compute instances attach-disk my-instance \
  --disk=my-data-disk \
  --zone=us-central1-a \
  --mode=rw \
  --device-name=data-disk

# Detach
gcloud compute instances detach-disk my-instance \
  --disk=my-data-disk \
  --zone=us-central1-a
```

---

## Networking

### VPC and Subnet

```bash
# Create custom VPC
gcloud compute networks create my-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

# Create subnet
gcloud compute networks subnets create my-subnet \
  --network=my-vpc \
  --region=us-central1 \
  --range=10.0.1.0/24 \
  --enable-private-ip-google-access
```

### Firewall Rules

```bash
# Allow SSH (targeted by tag)
gcloud compute firewall-rules create allow-ssh \
  --network=my-vpc \
  --direction=INGRESS --priority=1000 \
  --rules=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=ssh-allowed

# Allow HTTP/HTTPS
gcloud compute firewall-rules create allow-http-https \
  --network=my-vpc \
  --direction=INGRESS --priority=1000 \
  --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server,https-server

# List firewall rules
gcloud compute firewall-rules list \
  --filter="network:my-vpc" \
  --format="table(name,direction,priority,allowed[].map().firewall_rule().list())"
```

### Static IPs

```bash
# External static IP
gcloud compute addresses create my-static-ip \
  --region=us-central1 \
  --network-tier=PREMIUM

# Internal static IP
gcloud compute addresses create my-internal-ip \
  --region=us-central1 \
  --subnet=my-subnet \
  --addresses=10.0.1.100

# List addresses
gcloud compute addresses list --filter="region:us-central1"
```

---

## SSH and Remote Access

### SSH via gcloud

```bash
# SSH (gcloud manages keys automatically)
gcloud compute ssh my-instance --zone=us-central1-a

# SSH as specific user
gcloud compute ssh my-user@my-instance --zone=us-central1-a

# SSH through IAP (no external IP needed)
gcloud compute ssh my-instance \
  --zone=us-central1-a \
  --tunnel-through-iap

# Run command remotely
gcloud compute ssh my-instance \
  --zone=us-central1-a \
  --command="sudo systemctl status nginx"
```

### SCP File Transfer

```bash
# Copy file to instance
gcloud compute scp ./local-file.txt my-instance:/tmp/ \
  --zone=us-central1-a

# Copy file from instance
gcloud compute scp my-instance:/var/log/syslog ./local-syslog.txt \
  --zone=us-central1-a

# Recursive copy
gcloud compute scp --recurse ./local-dir/ my-instance:/tmp/ \
  --zone=us-central1-a
```

### Metadata Scripts

```bash
# Add startup script
gcloud compute instances add-metadata my-instance \
  --zone=us-central1-a \
  --metadata-from-file=startup-script=./startup.sh

# Add shutdown script
gcloud compute instances add-metadata my-instance \
  --zone=us-central1-a \
  --metadata-from-file=shutdown-script=./shutdown.sh

# Set inline metadata
gcloud compute instances add-metadata my-instance \
  --zone=us-central1-a \
  --metadata=enable-oslogin=true,serial-port-enable=true
```

---

## Monitoring

### Serial Port Output (Console Logs)

```bash
# Get serial port output (boot logs, kernel messages)
gcloud compute instances get-serial-port-output my-instance \
  --zone=us-central1-a

# Stream from beginning
gcloud compute instances get-serial-port-output my-instance \
  --zone=us-central1-a --start=0
```

### Cloud Logging

```bash
# Instance activity logs
gcloud logging read \
  'resource.type="gce_instance" AND resource.labels.instance_id="1234567890"' \
  --limit=50 --format=json

# System event logs
gcloud logging read \
  'resource.type="gce_instance" AND logName="projects/my-project/logs/cloudaudit.googleapis.com%2Factivity" AND resource.labels.instance_id="1234567890"' \
  --limit=20

# Serial port logs
gcloud logging read \
  'resource.type="gce_instance" AND logName="projects/my-project/logs/serialconsole.googleapis.com%2Fserial_port_1_output"' \
  --limit=100
```

### Instance Status

```bash
gcloud compute instances describe my-instance \
  --zone=us-central1-a \
  --format="value(status,lastStartTimestamp,lastStopTimestamp)"
```

---

## Instance Templates and MIGs

### Instance Templates

```bash
# Create instance template
gcloud compute instance-templates create my-template \
  --machine-type=n2-standard-4 \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-ssd \
  --tags=http-server \
  --metadata=enable-oslogin=true \
  --labels=env=production
```

### Managed Instance Groups

```bash
# Create MIG with auto-scaling
gcloud compute instance-groups managed create my-mig \
  --zone=us-central1-a \
  --template=my-template \
  --size=3

# Set auto-scaling
gcloud compute instance-groups managed set-autoscaling my-mig \
  --zone=us-central1-a \
  --min-num-replicas=2 \
  --max-num-replicas=10 \
  --target-cpu-utilization=0.7

# Rolling update to new template
gcloud compute instance-groups managed rolling-action start-update my-mig \
  --zone=us-central1-a \
  --version=template=my-new-template \
  --max-surge=1 \
  --max-unavailable=0
```

---

## Useful Configuration Defaults

```bash
# Set default zone and region to avoid --zone on every command
gcloud config set compute/zone us-central1-a
gcloud config set compute/region us-central1
gcloud config set project my-project

# Verify current configuration
gcloud config list
```
