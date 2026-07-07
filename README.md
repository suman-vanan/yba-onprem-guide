# YugabyteDB Anywhere (YBA) & YugabyteDB (YBDB) On-Premises Installation Guide

## Table of Contents

### Part A — YBA Deployment (Management Plane)

1. [Architecture Overview](#1-architecture-overview)
2. [VM Provisioning](#2-vm-provisioning)
3. [Networking & Port Requirements](#3-networking--port-requirements)
4. [YBA Node — Prerequisites](#4-yba-node--prerequisites)
5. [Install YugabyteDB Anywhere (YBA)](#5-install-yugabytedb-anywhere-yba)
6. [YBA Initial Setup (UI)](#6-yba-initial-setup-ui)

### Part B — YBDB Deployment (Data Plane — 3-Node Cluster)

7. [Database Nodes — Prerequisites (All Nodes)](#7-database-nodes--prerequisites-all-nodes)
8. [Provision Database Nodes (Node Agent Method)](#8-provision-database-nodes-node-agent-method)
9. [Create On-Premises Provider Configuration](#9-create-on-premises-provider-configuration)
10. [Create a 3-Node Universe (RF=3)](#10-create-a-3-node-universe-rf3)
11. [Post-Deployment Validation](#11-post-deployment-validation)
12. [Configure Backup with NFS](#12-configure-backup-with-nfs)  
12A. [Configure Backup with S3-Compatible Storage (Commvault)](#12a-configure-backup-with-s3-compatible-storage-commvault)
13. [Setup xCluster DR](#13-setup-xcluster-dr)

### Operations

14. [Upgrading YBA](#14-upgrading-yugabytedb-anywhere-yba)

### Appendix

15. [Useful Commands](#15-appendix--useful-commands)
16. [Summary Checklist](#16-quick-reference--summary-checklist)

---

# Part A — YBA Deployment (Management Plane)

---

## 1. Architecture Overview

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                                           │
│  ┌────────────────────────────────────────────────────────┐   ┌────────────────────────────────────────────────────────┐  │
│  │                      Datacenter 1                      │   │                      Datacenter 2                      │  │
│  │                                                        │   │                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │  DB Node 1   │  │  DB Node 2   │  │  DB Node 3   │  │   │  │  DB Node 4   │  │  DB Node 5   │  │  DB Node 6   │  │  │
│  │  │              │  │              │  │              │  │   │  │              │  │              │  │              │  │  │
│  │  │  YB-Master   │  │  YB-Master   │  │  YB-Master   │  │   │  │  YB-Master   │  │  YB-Master   │  │  YB-Master   │  │  │
│  │  │  YB-TServer  │  │  YB-TServer  │  │  YB-TServer  │  │   │  │  YB-TServer  │  │  YB-TServer  │  │  YB-TServer  │  │  │
│  │  │  Node Agent  │  │  Node Agent  │  │  Node Agent  │  │   │  │  Node Agent  │  │  Node Agent  │  │  Node Agent  │  │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │   │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │  │
│  │         │                 │                 │          │   │         │                 │                 │          │  │
│  │         └─────────────────┴─────────────────┘          │   │         └─────────────────┴─────────────────┘          │  │
│  │                           │                            │   │                           │                            │  │
│  └───────────────────────────┴────────────────────────────┘   └───────────────────────────┴────────────────────────────┘  │
│                              │                                                              │                             │
│                              └─────────────────────────────┬────────────────────────────────┘                             │
│                                                            │                                                              │
│                                            ┌───────────────┴───────────────┐                                              │
│                                            │        YBA Node (Mgmt)        │                                              │
│                                            │                               │                                              │
│                                            │   YBA Platform + Prometheus   │                                              │
│                                            │     PostgreSQL (internal)     │                                              │
│                                            └───────────────────────────────┘                                              │
│                                                                                                                           │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

For more details, see the reference architecture diagram:
![Reference Architecture](image/RA.png)


**Components:**

| Role                   | Count | Purpose                                                                      |
| ---------------------- | ----- | ---------------------------------------------------------------------------- |
| YBA Node               | 1     | Management plane — runs YugabyteDB Anywhere, Prometheus, internal PostgreSQL |
| Data Migration Service | 1     | Migration Service (to migrate from MS SQL / Postgres)                        |
| DB Nodes               | 6-7   | Data plane — runs YB-Master, YB-TServer, Node Agent                          |

> **Important:** Keep the YBA (control plane) node separate from the database cluster nodes (data plane).

---

## 2. VM Provisioning

Create **8-9 VMs** (1 YBA + 1 DMS + 6-7 DB nodes).
**3-4s** DB nodes should be in DC, and **3** nodes in DR.

| S.No                                   | Node Type                  | Node Identifier \*  | Count         | vCPU \*\* / node | Memory (GB) \*\* / node | Volumes (disks) / node | Storage (GB) \*\* /node | Total Storage(GB) / node | Volume Type | Role                                                  |
| :------------------------------------- | :------------------------- | :------------------ | :------------ | :--------------- | :---------------------- | :--------------------- | :---------------------- | :----------------------- | :---------- | :---------------------------------------------------- |
| 1                                      | Mgmt Node                  | **yb_ybap**         | 1             | 4                | 16                      | 1                      | 150                     | 150                      | SSD         | DBaaS control plane                                   |
| 2                                      | Database Migration Service | **yb_migration**    | 1             | 4                | 16                      | 1                      | 300                     | 300                      | SSD         | Migration Service (to migrate from MS SQL / Postgres) |
| **Primary Universe (DC)**              |                            |                     |               |                  |                         |                        |                         |                          |             |                                                       |
| 3                                      | DB Node(s)                 | **ybp_n1..ybp_n\*** | 3 or 4 \*\*\* | 8                | 32                      | 1                      | 300                     | 300                      | SSD         | DB node(s)                                            |
| **Replica or Secondary Universe (DR)** |                            |                     |               |                  |                         |                        |                         |                          |             |                                                       |
| 4                                      | DB Node(s)                 | **ybr_n1..ybr_n\*** | 3             | 4 \*\*\*\*       | 16 \*\*\*\*             | 1                      | 300                     | 300                      | SSD         | DB node(s)                                            |

\* Node identifier is just an arbitrary name to identify nodes in the subsequent sections  
\*\* vCPU, Memory and Storage need to be adjusted based on the scope  
\*\*\* 4 nodes are needed to test horizontal scaling scenario, where we scale from 3 nodes to 4 nodes  
\*\*\*\* Replica (DR) universe follows *minimum specification* to compare with *ideal specification* in primary universe

---

## 3. Networking & Port Requirements

### Port Access

| S.No | Source                 | Target                                   | Ports                                                                                 |
| :--- | :--------------------- | :--------------------------------------- | :------------------------------------------------------------------------------------ |
| 1    | Intranet Network       | yb_ybap                                  | 443, 9090, 22 (Browser access is required for 443, 9090)                              |
| 2    | yb_ybap                | ybp_n1 .. ybp_n*                         | 7000, 9000, 12000, 13000, 14000, 22, 54422, 9300, 9042, 5433, 7100, 9100, 9070, 18018 |
| 3    | yb_ybap                | ybr_n1 .. ybr_n*                         | 7000, 9000, 12000, 13000, 14000, 22, 54422, 9300, 9042, 5433, 7100, 9100, 9070, 18018 |
| 4    | ybp_n1 .. ybp_n*       | yb_ybap                                  | 443                                                                                   |
| 5    | ybr_n1 .. ybr_n*       | yb_ybap                                  | 443                                                                                   |
| 6    | ybp_n1 .. ybp_n*       | ybp_n1 .. ybp_n*                         | 7000, 9000, 12000, 13000, 14000, 9300, 9042, 5433, 7100, 9100, 9070, 18018            |
| 7    | ybr_n1 .. ybr_n*       | ybr_n1 .. ybr_n*                         | 7000, 9000, 12000, 13000, 14000, 9300, 9042, 5433, 7100, 9100, 9070, 18018            |
| 8    | ybp_n1 .. ybp_n*       | ybr_n1 .. ybr_n*                         | 7100, 9100                                                                            |
| 9    | ybr_n1 .. ybr_n*       | ybp_n1 .. ybp_n*                         | 7100, 9100                                                                            |
| 10   | Intranet Network, Apps | ybp_n1 .. ybp_n*                         | 5433, 9042                                                                            |
| 11   | Intranet Network, Apps | ybr_n1 .. ybr_n*                         | 5433, 9042                                                                            |
| 12   | yb_migration           | ybp_n1 .. ybp_n* AND [REPLACE_SOURCE_DB] | 5433, [REPLACE_SOURCE_DB_PORT]                                                        |
| 13   | Intranet Network       | yb_migration                             | 22, 443 (Browser access is required for 443)                                          |

For additional details, please see the [networking requirements sections of docs](https://docs.yugabyte.com/stable/yugabyte-platform/prepare/networking/).

### Verify Port Connectivity

todo(suman): Update the script

Use `nc` (netcat) or the YugabyteDB port checker script to validate:

```bash
# From YBA node, test connectivity to a DB node
nc -zv <DB_NODE_IP> 9070   # Node Agent RPC
nc -zv <DB_NODE_IP> 7000   # YB-Master HTTP
nc -zv <DB_NODE_IP> 5433   # YSQL

# From DB node, test connectivity to YBA node
nc -zv <YBA_NODE_IP> 443   # HTTPS
```

> Reference: https://yugabytedb.tips/verify-required-ports-are-open-before-installing-yugabytedb-or-yba/

---

## 4. YBA Node — Prerequisites

Perform the following steps on the **YBA node** only.

### 4.1 Create the Admin User

```bash
sudo useradd -m -s /bin/bash ybadmin
sudo passwd ybadmin

echo "ybadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ybadmin
sudo chmod 440 /etc/sudoers.d/ybadmin
```

### 4.2 Install Python 3.11

YBA requires **Python 3.11**. Both `python` and `python3` must link to Python 3.11.

#### RHEL 9

```bash
sudo dnf install python3.11 -y
sudo alternatives --set python /usr/bin/python3.11
sudo alternatives --set python3 /usr/bin/python3.11

python --version    # Expected: Python 3.11.x
python3 --version   # Expected: Python 3.11.x
```

#### Known issue — `argcomplete` traceback on shell login after the alternatives switch

After switching `/usr/bin/python3` to point at Python 3.11, every interactive login (including `su - ybadmin`) may print one of these tracebacks:

```text
ModuleNotFoundError: No module named 'argcomplete'
```

or, after a partial fix attempt:

```text
AttributeError: module 'argcomplete' has no attribute 'autocomplete'
```

**Why:** RHEL ships `/usr/bin/register-python-argcomplete` (called by `/etc/profile.d/bash_completion.sh` on login) which uses `/usr/bin/python3`. After the alternative switch, that interpreter is Python 3.11, which (a) doesn't have the `argcomplete` module installed by the `python3-argcomplete` RPM (that one is for Python 3.9), and (b) is incompatible with the legacy launcher's old API even after you `pip install argcomplete` (the modern argcomplete 3.x removed the top-level `autocomplete()` function the RPM script calls).

**Fix — run on the YBA node (only this node switches to Python 3.11; DB nodes stay on 3.9 and are unaffected):**

```bash
sudo /usr/bin/python3.11 -m pip install --upgrade --force-reinstall \
  --target=/usr/lib/python3.11/site-packages argcomplete

sudo cp /usr/bin/register-python-argcomplete /usr/bin/register-python-argcomplete.rpm-orig
echo -e '#!/bin/bash\nexit 0' | sudo tee /usr/bin/register-python-argcomplete > /dev/null
sudo chmod +x /usr/bin/register-python-argcomplete

[ -f /usr/local/bin/register-python-argcomplete ] && \
  echo -e '#!/bin/bash\nexit 0' | sudo tee /usr/local/bin/register-python-argcomplete > /dev/null && \
  sudo chmod +x /usr/local/bin/register-python-argcomplete
```

What this does:
- Installs `argcomplete` into Python 3.11's **system** site-packages (`/usr/lib/python3.11/site-packages`) so `import argcomplete` works for `/usr/bin/python3.11`.
- Replaces the legacy RHEL launcher (and any pip-installed copy in `/usr/local/bin`) with a no-op so the incompatible-API call cannot fire on login. The original is preserved as `…rpm-orig` for rollback.

**Verify:**

```bash
/usr/bin/python3.11 -c "import argcomplete; print(argcomplete.__file__)"
exit
su - ybadmin    # should land cleanly with no traceback
```

> **Cosmetic only:** these scripts only drive bash tab-completion for argparse-based CLIs. Nothing in YBA, YBDB, or the node-agent depends on them — neutralising them has zero functional impact on the install.

### 4.3 Disable SELinux (if applicable)

```bash
getenforce

sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# Temporarily set to permissive until reboot
sudo setenforce 0

# Reboot to fully disable (recommended)
sudo reboot
```

### 4.4 Configure Firewall (if enabled)

If `firewalld` is running, open the required YBA ports:

```bash
sudo systemctl status firewalld

sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=9090/tcp --permanent
sudo firewall-cmd --zone=public --add-port=5432/tcp --permanent
sudo firewall-cmd --reload
```

### 4.5 Configure Time Synchronization (chrony)

```bash
sudo dnf install chrony -y
sudo systemctl enable chronyd
sudo systemctl start chronyd
```

Edit the chrony configuration:

```bash
sudo vi /etc/chrony.conf
```

Add or replace server lines:

```
server 0.rhel.pool.ntp.org iburst
server 1.rhel.pool.ntp.org iburst
server 2.rhel.pool.ntp.org iburst
```

Restart and verify:

```bash
sudo systemctl restart chronyd
chronyc sources -v
timedatectl
```

---

## 5. Install YugabyteDB Anywhere (YBA)

Perform these steps on the **YBA node**, logged in as **ybadmin**.

### 5.1 YBA Installer

```bash
sudo su - ybadmin
cd ~

# YBA Installer (v2025.2.3.2) should have been downloaded and moved to this airgapped VM

tar -xf yba_installer_full-2025.2.3.2-b1-linux-x86_64.tar.gz
cd yba_installer_full-2025.2.3.2-b1/
```

### 5.2 Place the License File (sent via email)

```bash
sudo mkdir -p /opt/yba-ctl
sudo cp /path/to/yba.lic /opt/yba-ctl/yba.lic
```

### 5.3 Run Preflight Checks

```bash
sudo ./yba-ctl preflight
```

If no config file exists at `/opt/yba-ctl/yba-ctl.yml`, the preflight command will automatically create one with default values and prompt:

```
No config file found at '/opt/yba-ctl/yba-ctl.yml', creating it with default values now.
Do you want to proceed with the default config? [yes/NO]:
```

- Answer **yes** to continue with defaults.
- Answer **no** to exit and edit the config before proceeding.

Review the preflight output and fix any reported issues before proceeding.

### 5.3.1 Change YBA Install Location (Optional)

By default, YBA installs to `/opt/yugabyte`. To change this, edit the config file **before** running install:

```bash
sudo vi /opt/yba-ctl/yba-ctl.yml
```

Change the `installRoot` value:

```yaml
# Default
installRoot: /opt/yugabyte

# Custom example
installRoot: /yugadb/yba
```

After editing, run preflight again to validate the new config:

```bash
sudo ./yba-ctl preflight
```

> **Note:** The `installRoot` cannot be changed after YBA is installed. The config file itself always remains at `/opt/yba-ctl/yba-ctl.yml` regardless of the install location.

> **Ownership note (YBA install root):** Do **not** pre-create or `chown` the install root itself (e.g. `/yugadb/yba`). Only create the **parent** directory (`sudo mkdir -p /yugadb`, `root:root`, mode `755`). `yba-ctl install` creates `/yugadb/yba` and sets per-service ownership on its subdirectories automatically:
>
> | Path | Owner after install |
> |------|---------------------|
> | `/yugadb/yba` (top-level) | `root:root` |
> | `/yugadb/yba/data/yb-platform/...` | `yugabyte:yugabyte` |
> | `/yugadb/yba/data/postgres/...` | `postgres:postgres` |
> | `/yugadb/yba/data/prometheus/...` | `prometheus:prometheus` |
> | `/yugadb/yba/software/...` | `root:root` |
>
> `ybadmin` does **not** own YBA files — it is only the login user that runs `sudo yba-ctl …` commands. All YBA processes run as the dedicated service users above, which are created by the installer. Preserve this ownership on upgrades as well; `yba-ctl upgrade` does not require any manual `chown`.

### 5.4 Install YBA

```bash
sudo ./yba-ctl install -l /opt/yba-ctl/yba.lic
```

If disk space check is an issue (e.g., NFS-mounted volumes), you can skip it:

```bash
sudo ./yba-ctl install -l /opt/yba-ctl/yba.lic --skip_preflight disk-availability
```

### 5.5 Verify Installation

After successful installation, you will see output similar to:

```
               YBA Url |   Install Root |            yba-ctl config |              yba-ctl Logs |
  https://<YBA_IP>     |  /opt/yugabyte |  /opt/yba-ctl/yba-ctl.yml |  /opt/yba-ctl/yba-ctl.log |

Services:
  Systemd service |          Version |  Port |  Running Status |
         postgres |            14.19 |  5432 |         Running |
       prometheus |            3.5.0 |  9090 |         Running |
      yb-platform |  2025.2.3.2-b1 |   443 |         Running |
     yb-logrotate |                  |     0 |         Running |

INFO  Successfully installed YugabyteDB Anywhere!
```

Check status at any time:

```bash
sudo yba-ctl status
```

### 5.6 Access the YBA UI

Open a browser and navigate to:

```
https://<YBA_NODE_IP>
```

> **Note:** YBA uses a self-signed certificate by default. Accept the browser warning to proceed.

---

## 6. YBA Initial Setup (UI)

### 6.1 Create Super Admin Account

1. Open `https://<YBA_NODE_IP>` in your browser.
2. Register the first (super admin) user:
   - **Full Name**
   - **Email**
   - **Password**
   - **Environment** (e.g., `demo` or `production`)
3. Click **Register**.

### 6.2 Generate API Token

You will need an API token for node provisioning later:

1. Click the **User Profile** icon (top-right).
2. Select **User Profile**.
3. Note the **Customer UUID** (you'll need this in Part B).
4. Under **API Key Management**, click **Generate Key**.
5. Copy and save the API token securely.

### 6.3 Configure Alerts (Optional)

Navigate to **Admin** > **Alerting & Notifications** to set up email/Slack alerts.

> **YBA deployment is now complete.** Proceed to Part B to set up the database nodes and create the YBDB cluster.

---

# Part B — YBDB Deployment (Data Plane — 3-4 Node Cluster in DC & 3 Node Cluster in DR)

---

## 7. Database Nodes — Prerequisites (All nodes)

Perform the following steps on **each of the database nodes**. It's recommended to perform all of the steps in sections 7 and 8 on one node first. Once working, the same steps can be repeated on the other nodes.

---

### 7.1 Create the Admin User

```bash
sudo useradd -m -s /bin/bash ybadmin
sudo passwd ybadmin

echo "ybadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ybadmin
sudo chmod 440 /etc/sudoers.d/ybadmin
```

### 7.2 Verify additional software for airgapped deployment

For airgapped VMs, the additional software below may need to be pre-installed:
- libcgroup (Not neccessary for RHEL 9)
- libcgroup-tools (Not neccessary for RHEL 9)
- rsync
- openssl
- glibc-locale-source
- glibc-langpack-en
- libatomic
- chrony
- polkit

Pre-installation is only required if the software package is not available in the local repository.

#### Check if connected to a local repository

```bash
# Look for your local repository's ID or name in the output
dnf repolist

# Provides detailed information
dnf repoinfo
```

If you have no available local repository for use, then the list of additional software needs to be pre-installed. Else, we can proceed to check if the required packages are available in the local repository.

#### Check required software

For each software package, we'll first check if it installed or missing. If it's missing, we check if it's available in the local repository.

```bash
rpm -q libcgroup # Not neccessary for RHEL 9
# If not installed, check availability on local repository by running the command below:
dnf info libcgroup

rpm -q libcgroup-tools # Not neccessary for RHEL 9
# If not installed, check availability on local repository by running the command below:
dnf info libcgroup-tools

rpm -q rsync
# If not installed, check availability on local repository by running the command below:
dnf info rsync

rpm -q openssl
# If not installed, check availability on local repository by running the command below:
dnf info openssl

rpm -q glibc-locale-source
# If not installed, check availability on local repository by running the command below:
dnf info glibc-locale-source

rpm -q glibc-langpack-en
# If not installed, check availability on local repository by running the command below:
dnf info glibc-langpack-en

rpm -q libatomic
# If not installed, check availability on local repository by running the command below:
dnf info libatomic

rpm -q chrony
# If not installed, check availability on local repository by running the command below:
dnf info chrony

rpm -q polkit
# If not installed, check availability on local repository by running the command below:
dnf info polkit
```

Software packages that are not installed AND not avialable in the local repository will need to be pre-installed.


### 7.3 Install Python 3.9

#### RHEL 9

```bash
sudo dnf install python3.9 -y

# Check if alternatives was already configured for python or python3, and proceed with EITHER option A OR option B
alternatives --display python
alternatives --display python3

# A: If alternatives already configured for python, then switch active version
sudo alternatives --set python /usr/bin/python3.9
sudo alternatives --set python3 /usr/bin/python3.9

# B: If no alternatives configured for python, then install a new link
sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
sudo alternatives --install /usr/bin/python python /usr/bin/python3.9 1

# Verify versions
python --version    # Expected: Python 3.9.x
python3 --version   # Expected: Python 3.9.x

# Install the Python SELinux package
sudo pip3 install selinux
python3 -c "import selinux; import sys; print(sys.version)"
```

### 7.4 Install policycoreutils (required by node-agent-provision script)

The provisioning script checks for `policycoreutils`. Install it before running the script on RHEL 9:

```bash
sudo dnf install -y policycoreutils python3-policycoreutils
```

### 7.5 Disable SELinux

```bash
getenforce
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
sudo setenforce 0
sudo reboot
```

Check that `getenforce` returns `Disabled` after the reboot

### 7.6 Configure Time Synchronization (chrony)

Clock synchronization is **critical** for YugabyteDB. All nodes must be time-synced.

```bash
sudo dnf install chrony -y
sudo systemctl enable chronyd
sudo systemctl start chronyd
```

Edit the chrony configuration to add NTP servers:

```bash
sudo vi /etc/chrony.conf
```

Add or replace the server lines (use internal NTP if available, otherwise public):

```
server 0.rhel.pool.ntp.org iburst
server 1.rhel.pool.ntp.org iburst
server 2.rhel.pool.ntp.org iburst
```

Restart and verify:

```bash
sudo systemctl restart chronyd

# Verify sources (look for ^* indicating a synced source)
chronyc sources -v

# Verify time sync status
timedatectl
# "NTP synchronized: yes" should appear
```

### 7.7 Prepare Data Directories

Create mount points for YugabyteDB data storage. If you have dedicated data disks attached:

```bash
# Example: single data disk at /dev/sdb
sudo mkfs.xfs /dev/sdb
sudo mkdir -p /data
sudo mount /dev/sdb /data

# Add to /etc/fstab for persistence
echo "/dev/sdb  /data  xfs  defaults  0 0" | sudo tee -a /etc/fstab

# If multiple data disks:
# sudo mkfs.xfs /dev/sdc && sudo mkdir -p /mnt/d0 && sudo mount /dev/sdc /mnt/d0
# sudo mkfs.xfs /dev/sdd && sudo mkdir -p /mnt/d1 && sudo mount /dev/sdd /mnt/d1
```

Ensure the directories are accessible (the provisioning script will create the `yugabyte` user later):

```bash
sudo chmod 755 /data
```

> **Ownership note:** At this stage `/data` should remain **`root:root`** with mode `755`. Do **not** `chown` it to `ybadmin`. The `node-agent-provision.sh` script (Section 8) creates the `yugabyte` OS user and automatically sets `/data` (and any other mount points listed under `instance_type > mount_points` in `node-agent-provision.yaml`) to **`yugabyte:yugabyte`**. YugabyteDB processes (`yb-master`, `yb-tserver`) run as the `yugabyte` user, so `yugabyte:yugabyte` is the correct final ownership — never `ybadmin`.

### 7.8 Open Required Ports on Database Nodes

If `firewalld` is active on the DB nodes:

```bash
# Inter-node communication
sudo firewall-cmd --zone=public --add-port=7000/tcp --permanent   # YB-Master HTTP
sudo firewall-cmd --zone=public --add-port=7100/tcp --permanent   # YB-Master RPC
sudo firewall-cmd --zone=public --add-port=9000/tcp --permanent   # YB-TServer HTTP
sudo firewall-cmd --zone=public --add-port=9100/tcp --permanent   # YB-TServer RPC
sudo firewall-cmd --zone=public --add-port=18018/tcp --permanent  # YB Controller RPC

# YBA → DB node communication
sudo firewall-cmd --zone=public --add-port=5433/tcp --permanent   # YSQL server
sudo firewall-cmd --zone=public --add-port=9042/tcp --permanent   # YCQL server
sudo firewall-cmd --zone=public --add-port=9070/tcp --permanent   # Node Agent RPC
sudo firewall-cmd --zone=public --add-port=9300/tcp --permanent   # Prometheus Node Exporter
sudo firewall-cmd --zone=public --add-port=12000/tcp --permanent  # YCQL API
sudo firewall-cmd --zone=public --add-port=13000/tcp --permanent  # YSQL API

sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

---

## 8. Provision Database Nodes (Node Agent Method)

Perform these steps on **each of the database nodes** as root or with sudo.

### 8.1 Download the Node Agent Package

**Option A — Download from YBA (recommended if nodes can reach YBA):**

```bash
# Run on each DB node
curl -k https://<YBA_NODE_IP>/api/v1/node_agents/download\?downloadType\=package\&os\=LINUX\&arch\=AMD64 \
  --fail \
  --header 'X-AUTH-YW-API-TOKEN: <YOUR_API_TOKEN>' \
  > node-agent.tar.gz
```

**Option B — Direct download (if nodes have internet but not access to YBA):**

```bash
wget https://downloads.yugabyte.com/releases/2025.2.1.0/yba_installer_full-2025.2.3.2-b1-linux-x86_64.tar.gz
tar -xf yba_installer_full-2025.2.3.2-b1-linux-x86_64.tar.gz
cd yba_installer_full-2025.2.3.2-b1/
tar -xf yugabundle-2025.2.3.2-b1-centos-x86_64.tar.gz
cd yugabyte-2025.2.3.2-b1/
tar -xf node_agent-2025.2.3.2-b1-linux-amd64.tar.gz
```

**Option C — Airgapped (copy from YBA node):**

```bash
# On YBA node, download the package
curl -k https://localhost/api/v1/node_agents/download\?downloadType\=package\&os\=LINUX\&arch\=AMD64 \
  --fail \
  --header 'X-AUTH-YW-API-TOKEN: <YOUR_API_TOKEN>' \
  > node-agent.tar.gz

# SCP to each DB node
scp node-agent.tar.gz ybadmin@<DB_NODE_IP>:/home/ybadmin/
```

### 8.2 Extract and Navigate to Scripts

```bash
tar -xvzf node-agent.tar.gz
cd 2025.2.3.2-b1/scripts/
```

### 8.2.1 Create `yb_home_dir` and `ynp_version` file (required for preflight)

The provisioning script expects a file **`ynp_version`** at `yb_home_dir/ynp_version`. If it is missing, preflight fails with:

```text
The ynp_version file was not found at <yb_home_dir>/ynp_version
```

**Create the install directory and the version file** before running the script. Use `/yugadb/install` as the install directory (or match the `yb_home_dir` value in your `node-agent-provision.yaml`) and set the version file content to `1.0.0`:

```bash
# Create directory and ynp_version file (use your actual yb_home_dir if different)
sudo mkdir -p /yugadb/install
echo "1.0.0" | sudo tee /yugadb/install/ynp_version
sudo chmod 644 /yugadb/install/ynp_version
```

Then run the preflight again: `sudo ./node-agent-provision.sh --preflight_check`.

### 8.3 Edit the Configuration File

```bash
vi node-agent-provision.yaml
```

-- Get the VM details
lscpu | grep -Ei 'model name|^CPU\(s\)|socket|core|thread|numa|hypervisor'

Update the following fields for each node:

| Field            | Value                                      | Description                                         |
| ---------------- | ------------------------------------------ | --------------------------------------------------- |
| `yb_home_dir`    | `/home/yugabyte`                           | YugabyteDB installation directory                   |
| `chrony_servers` | `0.rhel.pool.ntp.org, 1.rhel.pool.ntp.org` | NTP servers (use your internal NTP if available)    |
| `yb_user_id`     | `1001`                                     | Consistent UID for `yugabyte` user across all nodes |
| `node_ip`        | `<THIS_NODE_IP>`                           | IP of the current node being provisioned            |
| `tmp_directory`  | `/tmp`                                     | Temp directory                                      |
| `is_airgap`      | `false`                                    | Set `true` for airgapped                            |

# to get id 994 id is in use
getent passwd 994
getent group 994
getent passwd 1001 || echo "UID 1001 is free"
getent group 1001 || echo "GID 1001 is free"

**Provider configuration fields** (to auto-create/update the on-prem provider):

| Field                          | Value                                       | Description                                       |
| ------------------------------ | ------------------------------------------- | ------------------------------------------------- |
| `url`                          | `https://<YBA_NODE_IP>`                     | YBA base URL                                      |
| `customer_uuid`                | `<YOUR_CUSTOMER_UUID>`                      | From User Profile in YBA (Step 6.2)               |
| `api_key`                      | `<YOUR_API_TOKEN>`                          | From User Profile in YBA (Step 6.2)               |
| `node_name`                    | `db-node-1` (or `db-node-2`, `db-node-3`)   | Unique name for each node                         |
| `node_external_fqdn`           | `<THIS_NODE_IP>`                            | IP/FQDN accessible from YBA                       |
| `provider > name`              | `onprem-dc`                                 | Provider name                                     |
| `region > name`                | `dc1`                                       | Region name (e.g., datacenter name)               |
| `zone > name`                  | `rack1` (vary per node for fault isolation) | Zone name — use different zones for fault domains |
| `instance_type > name`         | `onprem-8cpu-16gb`                          | Instance type identifier                          |
| `instance_type > cores`        | `8`                                         | vCPU count                                        |
| `instance_type > memory_size`  | `16`                                        | RAM in GB                                         |
| `instance_type > volume_size`  | `200`                                       | Data disk size in GB                              |
| `instance_type > mount_points` | `/data`                                     | Mount points for data                             |

**Example zone distribution for 3 nodes (fault isolation):**

| Node      | Zone  |
| --------- | ----- |
| db-node-1 | rack1 |
| db-node-2 | rack2 |
| db-node-3 | rack3 |

> If all nodes are on the same rack, use the same zone — but distributing across zones is strongly recommended for high availability.

### 8.4 Run the Provisioning Script

If `/tmp` is mounted with **noexec**, the provisioning script can fail when running executables from `/tmp`. Remount `/tmp` with execute permission before running the script:

```bash
sudo mount -o remount,exec /tmp
```

Then run the provisioning script:

```bash
sudo ./node-agent-provision.sh --preflight_check
sudo ./node-agent-provision.sh
```

The script will:
- Create the `yugabyte` user
- Set ulimits and disable transparent hugepages
- Install the Node Agent
- Run preflight checks
- Create (or update) the on-premises provider in YBA
- Add the node to the provider

#### About the `yugabyte` OS User

The `yugabyte` operating system user created by the provisioning script is a **locked service account** by default — it has **no password set** and **no interactive login**. This is a security best practice for service accounts.

> **For compliance documentation:**
> "The `yugabyte` OS user is a non-interactive service account with no password (account is locked). It is used solely to run YugabyteDB processes. Access to the nodes is managed through the `ybadmin` user, and YBA communicates with nodes via the Node Agent service — not via SSH as the `yugabyte` user."

To verify the account is locked:

```bash
sudo passwd -S yugabyte
```

A locked account will show `LK` (locked) or `L` in the output.

**If compliance policy requires a password on every OS account**, you can set one explicitly after provisioning:

```bash
sudo passwd yugabyte
```

This will not affect YBA or YugabyteDB operations — the password is not used by any YugabyteDB component. It is purely to satisfy compliance requirements. Document the credential in your organization's secrets/credential vault.

### 8.5 Enable systemd linger for the `yugabyte` user

During node-agent-provision.sh the script emitted:
Failed to connect to bus: No medium found
This happens when a systemctl --user … / loginctl … call is made against the yugabyte user but the per-user D-Bus socket at /run/user/<UID>/bus doesn't exist — i.e. the user manager (user@<UID>.service) isn't running because no one is logged in as yugabyte and linger isn't enabled yet.

YBA 2024.2+ runs YugabyteDB services (yb-master, yb-tserver, yb-controller, yb-node-agent, etc.) under **user-level systemd** owned by the `yugabyte` user. Without linger enabled, the user's systemd manager (`user@<UID>.service`) and runtime directory (`/run/user/<UID>`) are **torn down whenever no one is logged in as that user** — which means user-scope YB services do not start on their own after a reboot, and YBA will mark the node unreachable.

Enabling linger creates a persistent flag (`/var/lib/systemd/linger/yugabyte`) that tells systemd to keep the user's manager and runtime directory alive **at boot and across logouts**, with no manual login required.

Run this on the DB node after provisioning completes, **before** the reboot in step 8.6:

```bash
sudo loginctl enable-linger yugabyte
```

Verify it took effect:

```bash
loginctl show-user yugabyte | grep -E 'Linger|RuntimePath|State'
ls -l /var/lib/systemd/linger/yugabyte
ls -ld /run/user/$(id -u yugabyte)
```

Expected output:

```
Linger=yes
RuntimePath=/run/user/<UID>
State=lingering        # or "active" if someone is currently logged in as yugabyte

-rw-r--r--. 1 root root 0 ... /var/lib/systemd/linger/yugabyte
drwx------. ... yugabyte yugabyte /run/user/<UID>
```

> **Healthy `State` values:** `lingering` (linger keeping the manager alive, no interactive session — the normal steady state on a DB node) or `active` (someone is logged in as `yugabyte`). If you see `closing` or `offline`, linger is not taking effect — re-run `sudo loginctl enable-linger yugabyte` and re-verify.

> **Why this is practically mandatory for on-prem YBDB:**
> Without linger, you will see intermittent `Failed to connect to bus: No medium found` errors, `yb-node-agent.service` failing to auto-start after reboots, and universe create/edit tasks hanging because YBA can't reach the node agent. It is the supported mechanism Yugabyte assumes is in place for user-systemd-based node deployments.

> **To undo** (not recommended in production): `sudo loginctl disable-linger yugabyte`.

### 8.6 Reboot the Node

```bash
sudo reboot
```

### 8.7 Verify Provisioning

After reboot, verify the Node Agent and user systemd manager are running **without** logging in as `yugabyte`:

```bash
ls -ld /run/user/$(id -u yugabyte)
sudo systemctl status "user@$(id -u yugabyte).service" --no-pager
sudo -u yugabyte XDG_RUNTIME_DIR=/run/user/$(id -u yugabyte) \
     systemctl --user status yb-node-agent.service --no-pager
sudo systemctl status node_exporter.service --no-pager
```

All four should report active/running. If `yb-node-agent.service` is not active after reboot, re-check that `sudo loginctl enable-linger yugabyte` was run in step 8.5.

In the YBA UI, navigate to `https://<YBA_NODE_IP>/nodeagent` to confirm the node agents are listed and active.

### 8.8 Repeat for All Database Nodes

Repeat steps 8.1–8.7 for **each database node**, changing:
- `node_ip` and `node_external_fqdn` to the respective node's IP
- `node_name` to a unique name (`db-node-1`, `db-node-2`, `db-node-3`)
- `zone > name` to distribute across fault domains

Also run `sudo loginctl enable-linger yugabyte` on **every** DB node — it is per-node, not cluster-wide.

---

## 9. Create On-Premises Provider Configuration

> **Note:** If you configured provider details in `node-agent-provision.yaml` (Step 8.3), the provider is **auto-created**. Skip to Step 10.

If you did **not** configure provider details in the YAML, create the provider manually:

### 9.1 Create Provider

1. In YBA UI, go to **Integrations** > **Infrastructure** > **On-Premises Datacenters**.
2. Click **Create On-Premises Provider**.
3. Fill in:
   - **Provider Name:** `onprem-dc`
   - **NTP Servers:** `0.rhel.pool.ntp.org, 1.rhel.pool.ntp.org, 2.rhel.pool.ntp.org`
   - **Home Directory:** `/home/yugabyte` (or your `yb_home_dir` from node-agent-provision)

### 9.2 Add Regions and Zones

Add region(s) and availability zones:

| Region | Zone  |
| ------ | ----- |
| dc1    | rack1 |
| dc1    | rack2 |
| dc1    | rack3 |

### 9.3 Add Instance Type

- **Name:** `onprem-8cpu-16gb`
- **Cores:** 8
- **Memory (GB):** 16
- **Volume Size (GB):** 300
- **Mount Points:** `/data`

### 9.4 Add Instances (Nodes)

Navigate to the provider, click **Add Instances**:

| Instance Name | IP Address | Zone  |
| ------------- | ---------- | ----- |
| db-node-1     | x.x.x.x    | rack1 |
| db-node-2     | x.x.x.x    | rack2 |
| db-node-3     | x.x.x.x    | rack3 |

### 9.5 Run Preflight Checks

Click the **Preflight Check** button for each instance. All checks must pass before proceeding.

---

## 10. Create two 3-Node Universes (RF=3)

> Note: If you plan to test upgrading Universe versions, you may provision a Universe with an older version first (for example, `2025.2.3.2-b1`)

The sections below will need to be completed twice to create two universes: one universe in DC, and one universe in DR.

### 10.1 Navigate to Universe Creation

1. In YBA UI, go to **Universes** > **Create Universe**.

### 10.2 Configure General Settings

| Setting                | Value                             |
| ---------------------- | --------------------------------- |
| **Universe Name**      | `univ-a` (or your preferred name) |
| **Provider**           | `onprem-dc`                       |
| **Regions**            | `dc1`                             |
| **Total Nodes**        | `3`                               |
| **Replication Factor** | `3`                               |

### 10.3 Configure Instance

| Setting           | Value              |
| ----------------- | ------------------ |
| **Instance Type** | `onprem-8cpu-32gb` |

### 10.4 Configure Availability Zones

Assign nodes across zones:

| Zone  | Nodes |
| ----- | ----- |
| rack1 | 1     |
| rack2 | 1     |
| rack3 | 1     |

### 10.5 Configure Database Settings

| Setting       | Value                                   |
| ------------- | --------------------------------------- |
| **YSQL**      | Enabled                                 |
| **YSQL Auth** | Enabled (set password)                  |
| **YCQL**      | Enabled (optional)                      |
| **YCQL Auth** | Enabled (set password, if YCQL enabled) |

### 10.6 Configure Security (Optional but Recommended)

- **Encryption in Transit (TLS):** Enable Node-to-Node and Client-to-Node
- **Encryption at Rest:** Enable if required

> Review version:

### 10.7 Review and Create

1. Review the configuration summary.
2. Click **Create**.
3. Wait for the universe creation to complete (typically 10–20 minutes).

### 10.8 Monitor Creation Progress

- The **Tasks** tab shows the deployment progress.
- Each step (provisioning, configuring, starting) is listed with status indicators.

---

## 11. Post-Deployment Validation

### 11.1 Verify Universe Health in YBA UI

1. Go to **Universes** > click your universe name.
2. Check:
   - All 3 nodes show **Live** status.
   - **Masters** tab shows 3 masters (1 Leader, 2 Followers).
   - **Tablet Servers** tab shows 3 TServers.
   - **Metrics** tab shows data flowing.

### 11.2 Access YB-Master Web UI

```
http://<ANY_DB_NODE_IP>:7000
```

Verify 3 masters and 3 tservers are listed.

### 11.3 Connect via YSQL

```bash
# Using ysqlsh (available on DB nodes)
/home/yugabyte/tserver/bin/ysqlsh -h <DB_NODE_IP> -p 5433 -U yugabyte

# Or using psql from any machine with connectivity
psql -h <DB_NODE_IP> -p 5433 -U yugabyte -d yugabyte
```

### 11.4 Connect via YCQL (if enabled)

```bash
/home/yugabyte/tserver/bin/ycqlsh <DB_NODE_IP> 9042
```

### 11.5 Run a Simple Test

```sql
CREATE TABLE test_table (id INT PRIMARY KEY, name TEXT);
INSERT INTO test_table VALUES (1, 'hello'), (2, 'world');
SELECT * FROM test_table;
DROP TABLE test_table;
```

---

## 12. Configure Backup with NFS

This section describes how to use an **NFS file share** as the backup storage location for YugabyteDB universe backups. The **database nodes** (not the YBA node) must have the NFS share mounted at the **same path** on every node, and the `yugabyte` user must have read and write permissions on that path.

### 12.1 Prerequisites

| Requirement     | Description                                                                                                                                                            |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **NFS server**  | An NFS server that exports a dedicated share for YugabyteDB backups (e.g. `export /export/yb_backups`).                                                                |
| **Network**     | All **3 database nodes** can reach the NFS server over the network (typically NFS over TCP, port 2049). Ensure firewall allows NFS (e.g. `nfs`, `rpc-bind`, `mountd`). |
| **NFS client**  | Package `nfs-utils` (or `nfs-common` on Debian/Ubuntu) installed on **each database node**.                                                                            |
| **Mount path**  | A **common path** on all DB nodes where the NFS share will be mounted (e.g. `/backup` or `/yugadb/backups`). This path is what you will configure in YBA.              |
| **Permissions** | The `yugabyte` user (UID used in `node-agent-provision.yaml`) must have **read, write, and execute** on the mounted directory on every DB node.                        |
| **Persistence** | The NFS mount must be added to `/etc/fstab` on each DB node so it survives reboots; otherwise backup/restore can fail after a VM restart.                              |

### 12.2 Mount NFS on Each Database Node

Perform these steps on **each of the 3 database nodes**. Use the same mount path on all nodes (e.g. `/backup`).

**1. Install NFS client (RHEL 9):**

```bash
sudo dnf install -y nfs-utils
```

**2. Create the mount point:**

```bash
sudo mkdir -p /backup
```

**3. Mount the NFS share (replace with your NFS server and export path):**

```bash
# Example: NFS server 10.0.0.100 exports /export/yb_backups
sudo mount -t nfs <NFS_SERVER_IP>:/<EXPORT_PATH> /backup

# Example:
# sudo mount -t nfs 10.0.0.100:/export/yb_backups /backup
```

**4. Set ownership on the <u>NFS Server</u> so the `yugabyte` user can read/write (use the same UID as in your node-agent config, e.g. 1002):**

For example, if `1002` is the UID in our node-agent config: 
```bash
sudo chown -R 1002:1002 /backup
sudo chmod 755 /backup
```

**5. Add to `/etc/fstab` so the mount persists across reboots:**

```bash
# Add a line (replace <NFS_SERVER_IP> and <EXPORT_PATH> with your values)
echo "<NFS_SERVER_IP>:/<EXPORT_PATH>  /backup  nfs  defaults,_netdev  0  0" | sudo tee -a /etc/fstab

# Example:
# echo "10.0.0.100:/export/yb_backups  /backup  nfs  defaults,_netdev  0  0" | sudo tee -a /etc/fstab
```

**6. Verify the mount:**

```bash
mount | grep /backup
ls -la /backup
# Ensure yugabyte can write (run as yugabyte or use sudo -u yugabyte touch /backup/test && rm /backup/test)
sudo -u yugabyte touch /backup/test && sudo -u yugabyte rm /backup/test && echo "OK"
```

### 12.3 Configure NFS Backup in YBA UI

1. Log in to **YugabyteDB Anywhere** as a user with permission to manage backup configs (e.g. Super Admin).
2. Go to **Configs** (or **Integrations**) → **Backup** → **Network File System**.
3. Click **Create NFS Backup**.
4. Fill in:
   - **Configuration Name:** e.g. `nfs-uat-backups`
   - **NFS Storage Path:** the path **on the database nodes** where the NFS share is mounted (e.g. `/backup`). This must be the same path on all DB nodes.
5. Click **Save**.

### 12.4 Create or Schedule a Backup

- **One-time backup:** In **Universes** → select your universe → **Backups** → **Create Backup**. Choose the NFS storage configuration you created and run the backup.
- **Scheduled backups:** Use **Backups** → **Scheduled Backups** (or the schedule option in the backup flow) to set up recurring full or incremental backups to the NFS config.

### 12.5 Important Notes

- **Path consistency:** The **NFS Storage Path** in YBA must match the mount point on **every** database node (e.g. `/backup`). Backup and restore run on the DB nodes and write/read from this path.
- **fstab:** Adding the NFS mount to `/etc/fstab` on each DB node avoids backup failures after a VM restart when the mount would otherwise be missing.
- **Reference:** [Configure backup storage (YugabyteDB Docs)](https://docs.yugabyte.com/stable/yugabyte-platform/back-up-restore-universes/configure-backup-storage/).

---

## 12A. Configure Backup with S3-Compatible Storage (Commvault)

> **Applicable to:** YBA **2025.2.2.2** and later.

This section describes how to configure an **S3-compatible backup provider** (e.g., Commvault) for YugabyteDB universe backups. This is used when backups are stored on an on-premises S3-compatible object store rather than AWS S3 or NFS.

### 12A.1 Prerequisites

| Requirement                | Description                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------- |
| **YBA version**            | 2025.2.2.2 or later                                                                    |
| **S3-compatible endpoint** | The Commvault or other S3-compatible storage endpoint URL (e.g., `http://10.11.30.38`) |
| **Access Key & Secret**    | Credentials for the S3-compatible storage                                              |
| **S3 Bucket**              | A pre-created bucket on the S3-compatible storage (e.g., `s3://s3bucket`)              |
| **Network**                | All database nodes must be able to reach the S3-compatible endpoint                    |

### 12A.2 Enable Required Feature Flags

In YBA 2025.2.2.2, some S3-compatible configuration options are not visible in the Backup UI by default. You must enable the feature flags before configuring the provider.

**Flag 1 — `yb.ui.feature_flags.enable_path_style_access`**

This flag **is available** in the YBA UI:

1. Navigate to **Admin** > **Advanced** > **Global Configuration**.
2. Search for `yb.ui.feature_flags.enable_path_style_access`.
3. Set its value to `true`.

**Flag 2 — `yb.ui.feature_flags.enable_signing_region`**

This flag is **NOT visible** in the UI in 2025.2.2.2. Enable it via the API:

```bash
curl -k -X PUT \
  "https://<YBA_HOST>/api/v1/customers/<CUSTOMER_UUID>/runtime_config/00000000-0000-0000-0000-000000000000/key/yb.ui.feature_flags.enable_signing_region" \
  -H "X-AUTH-YW-API-TOKEN: <YOUR_API_TOKEN>" \
  -H "Content-Type: text/plain" \
  -d "true"
```

**Flag 3 — `yb.ui.feature_flags.enable_chunked_encoding`**

Enable this flag to make the Chunked Encoding toggle visible in the UI:

```bash
curl -k -X PUT \
  "https://<YBA_HOST>/api/v1/customers/<CUSTOMER_UUID>/runtime_config/00000000-0000-0000-0000-000000000000/key/yb.ui.feature_flags.enable_chunked_encoding" \
  -H "X-AUTH-YW-API-TOKEN: <YOUR_API_TOKEN>" \
  -H "Content-Type: text/plain" \
  -d "true"
```

> **Note:** Replace `<YBA_HOST>`, `<CUSTOMER_UUID>`, and `<YOUR_API_TOKEN>` with your actual values. The UUID `00000000-0000-0000-0000-000000000000` is the global scope identifier for runtime configuration.

After setting all three flags, refresh the YBA UI. The **S3 Path Style Access**, **Signing Region**, and **S3 Chunked Encoding** fields will now appear in the S3 backup configuration form.

### 12A.3 Configure the S3-Compatible Backup Provider in YBA UI

1. Log in to **YugabyteDB Anywhere**.
2. Navigate to **Integrations** > **Backup** > **Amazon S3**.
3. Fill in the following:

| Field                    | Value                     | Notes                                                                   |
| ------------------------ | ------------------------- | ----------------------------------------------------------------------- |
| **Configuration Name**   | e.g., `commvault-backup`  | A descriptive name for this backup config                               |
| **IAM Role**             | Off                       | Not applicable for on-prem S3-compatible storage                        |
| **Access Key**           | `<YOUR_ACCESS_KEY>`       | Provided by your Commvault / S3-compatible storage admin                |
| **Access Secret**        | `<YOUR_ACCESS_SECRET>`    | Provided by your Commvault / S3-compatible storage admin                |
| **S3 Bucket**            | `s3://<BUCKET_NAME>`      | e.g., `s3://s3bucket`                                                   |
| **S3 Bucket Host Base**  | `http://<S3_ENDPOINT_IP>` | The Commvault S3-compatible endpoint (e.g., `http://10.11.30.38`)       |
| **Signing Region**       | `us-east-1`               | Required but can be any valid region string for on-prem endpoints       |
| **S3 Path Style Access** | **On** (enabled)          | Required for most S3-compatible storage (non-AWS)                       |
| **S3 Chunked Encoding**  | **Off** (disabled)        | Must be disabled — Commvault does not support chunked transfer encoding |

4. Click **Save**.

### 12A.4 Important Notes

- **S3 Path Style Access** must be **enabled** for on-premises S3-compatible endpoints. Without it, YBA uses virtual-hosted-style URLs (`http://bucket.host/`) which do not work with most non-AWS S3 implementations.
- **S3 Chunked Encoding** must be **disabled** for Commvault and many other S3-compatible backends that do not support `Transfer-Encoding: chunked`.
- The **Signing Region** value (`us-east-1`) is required by the S3 signing protocol but has no functional impact for on-premises endpoints — any valid region string works.
- After saving, you can use this backup configuration when creating one-time or scheduled backups for your universe (**Universes** > select universe > **Backups** > **Create Backup**).

---

## 13. Setup xCluster DR

This section describes how to set up **xCluster DR** for in YBA for two universes: DR primary universe which will serve reads and writes, and the DR replica.

Ensure the following pre-requisites are met:
- Both universes are running the same version of YugabyteDB
- Both universes have the same encryption in transit settings
- They can be backed up and restored using the **same storage configuration**
- Network connectivity pre-requisites are met

Steps to set up xCluste DR (Automatic Mode):
1. Nvaigate to YBA UI
2. Navigate to your DR primary universe **xCluster Disaster Recovery** tab, and select the replication configuration
3. Click Configure & Enable Disaster Recovery
4. Enter a name for the DR configuration
5. Select the **universe** to use as the **DR replica**
6. Select the YSQL databases to be copied to the DR replica for disaster recovery. (Note that all tables in the database are added to replication; you cannot select a subset of tables.)
7. If data needs to be copied, click Next: Confirm Full Copy, and select a storage configuration.
8. Click Next: Configure PITR Settings. Set the retention period for PITR snapshots, or use default values.
9. Click Next: Confirm Alert Threshold. Use default values.
10. Click Confirm and Enable Disaster Recovery.

YugabyteDB Anywhere proceeds to set up DR for the universe, and the duration depends mainly on the amount of data that needs to be copied to the DR replica.

---

## 14. Upgrading YugabyteDB Anywhere (YBA)

Perform these steps on the **YBA node**, logged in as **ybadmin**.

### 14.1 Pre-Upgrade Checklist

Before upgrading, ensure the following:

- [ ] Confirm the target YBA version and review the [release notes](https://docs.yugabyte.com/preview/releases/yba-releases/) for breaking changes
- [ ] Take a snapshot/backup of the YBA VM (recommended)
- [ ] Verify current YBA is healthy: `sudo yba-ctl status`
- [ ] No universe operations (backup, restore, edit, etc.) are in progress
- [ ] Ensure sufficient disk space on the YBA node for the new installer

### 14.2 Download the New YBA Installer

```bash
sudo su - ybadmin
cd ~

# Download the new version (adjust version as needed)
wget https://downloads.yugabyte.com/releases/<NEW_VERSION>/yba_installer_full-<NEW_VERSION>-linux-x86_64.tar.gz

tar -xf yba_installer_full-<NEW_VERSION>-linux-x86_64.tar.gz
cd yba_installer_full-<NEW_VERSION>/
```

### 14.3 Run Preflight Checks

```bash
sudo ./yba-ctl preflight
```

Review the output and resolve any issues before proceeding.

### 14.4 Upgrade YBA

```bash
sudo ./yba-ctl upgrade
```

> **Note:** Use `upgrade`, **not** `install`. The `upgrade` command preserves your existing configuration, database, and provider settings.

If disk space check is an issue (e.g., NFS-mounted volumes), you can skip it:

```bash
sudo ./yba-ctl upgrade -l /opt/yba-ctl/yba.lic --skip_preflight disk-availability
```

### 14.5 Verify the Upgrade

```bash
sudo yba-ctl status
```

Confirm the new version is shown under the `yb-platform` service and all services are in **Running** status.

Then open the YBA UI at `https://<YBA_IP>` and verify:
- You can log in successfully
- The version shown in the UI matches the target version (check **Admin** > **Runtime Configuration** or the footer)
- All universes are healthy and nodes show **Live** status
- Node agents are connected and active

### 14.6 Post-Upgrade Steps

- If the release notes mention node agent upgrades, the node agents on database nodes will be upgraded automatically by YBA during the next universe operation, or you can trigger it manually from the YBA UI.
- Review any new configuration options introduced in the new version.
- Update your internal documentation with the new version number.

---

## 15. Appendix — Useful Commands

### YBA Management (on YBA node)

```bash
sudo yba-ctl status
sudo yba-ctl restart
sudo yba-ctl stop
sudo yba-ctl start
sudo yba-ctl reconfigure

# View logs
tail -f /opt/yugabyte/data/logs/application.log

# Clean installation (destructive — removes everything)
sudo yba-ctl clean --all
```

### YBA Configuration File

```bash
sudo vi /opt/yba-ctl/yba-ctl.yml
```

### Node Agent (on DB nodes)

```bash
systemctl status yb-node-agent
journalctl -u yb-node-agent -f
```

### Time Sync Verification (all nodes)

```bash
chronyc sources -v
timedatectl
chronyc tracking
```

### Port Verification Script

```bash
#!/bin/bash
DB_NODE=$1
PORTS=(7000 7100 9000 9100 5433 9042 9070 9300 12000 13000 18018)

for port in "${PORTS[@]}"; do
  nc -zv -w3 $DB_NODE $port 2>&1
done
```

Usage: `./check_ports.sh <DB_NODE_IP>`

### SELinux Status

```bash
getenforce
sestatus
```

---

## 16. Quick Reference — Summary Checklist

### Part A — YBA Deployment

- [ ] YBA VM created with static IP
- [ ] `ybadmin` user created with passwordless sudo
- [ ] Python 3.11 installed (`python` and `python3` both linked)
- [ ] SELinux disabled
- [ ] Chrony configured and time-synced
- [ ] Firewall ports opened (443, 80, 9090, 5432)
- [ ] YBA Installer downloaded and extracted
- [ ] License file placed at `/opt/yba-ctl/yba.lic`
- [ ] `yba-ctl preflight` passed
- [ ] `yba-ctl install` completed successfully
- [ ] YBA UI accessible at `https://<YBA_IP>`
- [ ] Super admin account created
- [ ] API token generated and saved

### YBA Upgrade

- [ ] Target YBA version identified and release notes reviewed
- [ ] YBA VM snapshot/backup taken
- [ ] Current YBA healthy (`yba-ctl status` — all services running)
- [ ] No universe operations in progress
- [ ] New YBA installer downloaded and extracted
- [ ] `yba-ctl preflight` passed
- [ ] `yba-ctl upgrade` completed successfully
- [ ] All services running with new version (`yba-ctl status`)
- [ ] YBA UI accessible and showing correct version
- [ ] All universes healthy, node agents connected

### Part B — YBDB Deployment

- [ ] 8-9 DB VMs created with static IPs
- [ ] `ybadmin` user created with passwordless sudo on all nodes
- [ ] Python 3.9 installed on all nodes
- [ ] SELinux disabled on all nodes
- [ ] Chrony configured and time-synced on all nodes
- [ ] Data disks formatted and mounted on all nodes (`/data`)
- [ ] Firewall ports opened on all nodes per the port matrix
- [ ] Network connectivity verified (YBA ↔ DB nodes, DB ↔ DB nodes)
- [ ] Node agent package downloaded to each DB node
- [ ] `node-agent-provision.yaml` configured for each node
- [ ] `node-agent-provision.sh` executed on each node
- [ ] `sudo loginctl enable-linger yugabyte` run on each DB node (user-systemd persists across reboots)
- [ ] Nodes rebooted after provisioning
- [ ] Node agents visible and active in YBA UI
- [ ] On-premises provider configured with regions/zones
- [ ] Instance type defined
- [ ] All 3 nodes added and preflight checks passed
- [ ] Universe created with 3 nodes, RF=3
- [ ] All nodes show Live status
- [ ] YSQL/YCQL connectivity verified
- [ ] NFS share mounted on all 3 DB nodes at same path (e.g. `/backup`) with `yugabyte` ownership
- [ ] NFS mount added to `/etc/fstab` on each DB node
- [ ] NFS backup storage configuration created in YBA (Configs > Backup > Network File System)

---

## References

- [YBA Installation Overview](https://docs.yugabyte.com/stable/yugabyte-platform/yba-overview-install)
- [YBA Software Requirements](https://docs.yugabyte.com/stable/yugabyte-platform/prepare/server-yba/)
- [Database Node Requirements](https://docs.yugabyte.com/stable/yugabyte-platform/prepare/server-nodes/)
- [Node Agent Provisioning](https://docs.yugabyte.com/stable/yugabyte-platform/prepare/server-nodes-software/software-on-prem/)
- [On-Premises Provider Configuration](https://docs.yugabyte.com/stable/yugabyte-platform/configure-yugabyte-platform/on-premises/)
- [Add Nodes to Provider](https://docs.yugabyte.com/stable/yugabyte-platform/configure-yugabyte-platform/on-premises-nodes/)
- [Create a Universe](https://docs.yugabyte.com/preview/yugabyte-platform/create-deployments/create-universe-multi-zone/)
- [Networking Requirements](https://docs.yugabyte.com/stable/yugabyte-platform/prepare/networking/)
- [Port Verification Tool](https://yugabytedb.tips/verify-required-ports-are-open-before-installing-yugabytedb-or-yba/)
- [Configure backup storage (NFS, S3, GCS, Azure)](https://docs.yugabyte.com/stable/yugabyte-platform/back-up-restore-universes/configure-backup-storage/)
