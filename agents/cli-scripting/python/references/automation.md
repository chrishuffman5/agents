# Python Automation Reference

> System admin (psutil, platform), SSH (paramiko, fabric), email, scheduling, data processing (pandas).

---

## 1. System Administration

```python
import platform, socket, os, getpass

# Platform info
print(platform.system())           # "Linux", "Windows", "Darwin"
print(platform.node())             # hostname
print(platform.release())          # "22.04" / "10"
print(platform.machine())          # "x86_64", "arm64"
print(platform.python_version())

uname = platform.uname()
print(uname.system, uname.node, uname.release)

# Socket
hostname = socket.gethostname()
ip = socket.gethostbyname(hostname)
fqdn = socket.getfqdn()

# psutil (pip install psutil)
import psutil

# CPU
print(f"Cores: {psutil.cpu_count(logical=True)}")
print(f"Usage: {psutil.cpu_percent(interval=1)}%")
per_core = psutil.cpu_percent(percpu=True, interval=1)

# Memory
mem = psutil.virtual_memory()
print(f"RAM: {mem.used/1e9:.1f}/{mem.total/1e9:.1f} GB ({mem.percent}%)")
swap = psutil.swap_memory()

# Disk
for part in psutil.disk_partitions():
    try:
        usage = psutil.disk_usage(part.mountpoint)
        print(f"{part.device} -> {part.mountpoint}: {usage.percent}%")
    except PermissionError:
        pass

io = psutil.disk_io_counters()
print(f"Read: {io.read_bytes/1e6:.1f} MB, Write: {io.write_bytes/1e6:.1f} MB")

# Network
net = psutil.net_io_counters()
print(f"Sent: {net.bytes_sent/1e6:.1f} MB, Recv: {net.bytes_recv/1e6:.1f} MB")
for iface, addrs in psutil.net_if_addrs().items():
    for addr in addrs:
        if addr.family == socket.AF_INET:
            print(f"  {iface}: {addr.address}")

# Processes
for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
    try:
        info = proc.info
        if info["cpu_percent"] and info["cpu_percent"] > 10:
            print(f"PID {info['pid']} {info['name']}: CPU {info['cpu_percent']}%")
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass

# Kill by name
def kill_by_name(name):
    killed = 0
    for proc in psutil.process_iter(["name"]):
        if proc.info["name"] == name:
            proc.kill(); killed += 1
    return killed
```

---

## 2. SSH / Remote

```python
# pip install paramiko
import paramiko
from pathlib import Path

# SSHClient
def ssh_run(host, user, command, key_path="~/.ssh/id_rsa"):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=host, username=user,
                   key_filename=str(Path(key_path).expanduser()), timeout=10)
    stdin, stdout, stderr = client.exec_command(command, timeout=30)
    out = stdout.read().decode()
    err = stderr.read().decode()
    rc  = stdout.channel.recv_exit_status()
    client.close()
    return out, err, rc

out, err, rc = ssh_run("web01.example.com", "ubuntu", "df -h")

# SFTP upload/download
def sftp_upload(host, user, local, remote):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(host, username=user)
    with client.open_sftp() as sftp:
        sftp.put(str(local), remote)
        sftp.chmod(remote, 0o644)
    client.close()

# Fabric (pip install fabric) — higher-level SSH
from fabric import Connection

def deploy(host, user="ubuntu"):
    c = Connection(host=host, user=user)
    result = c.run("sudo systemctl restart nginx", hide=True)
    c.put("./deploy.tar.gz", remote="/tmp/deploy.tar.gz")
    c.close()

# Multiple hosts
from fabric import ThreadingGroup
group = ThreadingGroup(*[f"ubuntu@{h}" for h in ["web01", "web02"]])
group.run("sudo systemctl reload nginx")
```

---

## 3. Email

```python
import smtplib, ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from pathlib import Path

def send_email(smtp_host, smtp_port, sender, password, recipients,
               subject, body_text, body_html=None, attachments=None):
    msg = MIMEMultipart("alternative" if body_html else "mixed")
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = ", ".join(recipients)

    msg.attach(MIMEText(body_text, "plain", "utf-8"))
    if body_html:
        msg.attach(MIMEText(body_html, "html", "utf-8"))

    for attachment in (attachments or []):
        with attachment.open("rb") as f:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(f.read())
        encoders.encode_base64(part)
        part.add_header("Content-Disposition", f'attachment; filename="{attachment.name}"')
        msg.attach(part)

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(smtp_host, smtp_port, context=context) as server:
        server.login(sender, password)
        server.sendmail(sender, recipients, msg.as_string())

# Usage
send_email("smtp.gmail.com", 465, "alerts@example.com", "app_pw",
           ["ops@example.com"], "Disk alert", "Server web01 critical.",
           attachments=[Path("./report.csv")])
```

---

## 4. Scheduling

```python
# pip install schedule
import schedule, time, threading

def backup(): print("Running backup...")
def report(): print("Sending report...")

schedule.every().hour.do(backup)
schedule.every().day.at("08:00").do(report)
schedule.every(5).minutes.do(backup)

# Background thread
def run_scheduler():
    while True:
        schedule.run_pending(); time.sleep(1)
thread = threading.Thread(target=run_scheduler, daemon=True)
thread.start()

# APScheduler (pip install apscheduler)
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

scheduler = BackgroundScheduler()
scheduler.add_job(backup, CronTrigger(hour="*/4"))
scheduler.add_job(report, CronTrigger(hour=8, minute=0, day_of_week="mon-fri"))
scheduler.start()

# Cron integration
import subprocess
def install_cron_job(script_path, cron_schedule="0 * * * *"):
    result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
    existing = result.stdout if result.returncode == 0 else ""
    entry = f"{cron_schedule} /usr/bin/python3 {script_path}\n"
    if entry not in existing:
        subprocess.run(["crontab", "-"], input=existing + entry, text=True, check=True)
```

---

## 5. Data Processing (pandas)

```python
# pip install pandas openpyxl
import pandas as pd
from pathlib import Path

# Reading
df = pd.read_csv("data.csv", encoding="utf-8")
df = pd.read_csv("data.csv", dtype={"id": int}, parse_dates=["created_at"], na_values=["", "N/A"])
df = pd.read_excel("data.xlsx", sheet_name="Sheet1")
df = pd.read_json("data.json", orient="records")

# Inspection
print(df.shape, df.dtypes, df.head(), df.describe(), df.isnull().sum())

# Filtering
active = df[df["status"] == "active"]
combo  = df[(df["status"] == "active") & (df["score"] > 80)]

# Transformation
df["score_pct"] = df["score"] / df["score"].max() * 100
df["name_upper"] = df["name"].str.upper()
df.dropna(subset=["email"], inplace=True)
df.fillna({"score": 0}, inplace=True)
df.rename(columns={"id": "user_id"}, inplace=True)

# GroupBy
summary = df.groupby("department").agg(
    count=("name", "count"), avg_score=("score", "mean"), max_score=("score", "max"),
).reset_index()

# Merge
merged = pd.merge(df_users, df_orders, on="user_id", how="left")

# Pivot table
pivot = df.pivot_table(values="score", index="department", columns="status", aggfunc="mean")

# Output
df.to_csv("output.csv", index=False, encoding="utf-8")
df.to_json("output.json", orient="records", indent=2)
df.to_excel("output.xlsx", sheet_name="Results", index=False)

# Pipeline pattern
def process_sales(input_path, output_path):
    df = pd.read_csv(input_path, parse_dates=["sale_date"])
    df = df[df["amount"] > 0]
    df["month"] = df["sale_date"].dt.to_period("M")
    monthly = df.groupby(["month", "region"]).agg(
        total=("amount", "sum"), count=("amount", "count")
    ).reset_index()
    monthly.to_csv(output_path, index=False)
    return {"rows": len(df), "revenue": float(df["amount"].sum())}
```
