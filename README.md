# 🛡️ HAProxy TLS Passthrough Proxy on AWS

This Terraform project provisions a **highly available, scalable reverse proxy** using **HAProxy behind a Network Load Balancer (NLB)** on AWS. The proxy accepts incoming TLS connections and **passes them through to an upstream server** without terminating TLS (TLS passthrough).

---

## 📦 What It Deploys

- A **VPC** with two public subnets across two availability zones
- An **NLB** with **Elastic IPs** assigned for static IP addresses
- A **TCP Target Group** with health checks on a separate port (`9000`)
- An **Auto Scaling Group (ASG)** of EC2 instances running **HAProxy**
- **HAProxy** configured for:
  - TCP-level proxy on port `443`
  - Dedicated TCP health check on port `9000`
  - Daily log rotation for HAProxy logs
- **IAM roles** to allow EC2 access via AWS SSM (Session Manager)
- A basic **logging system** using `rsyslog` and `logrotate`

---

## 📋 Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) v1.0+
- AWS CLI (`aws configure`)
- AWS credentials with permissions to manage:
  - VPC and subnet resources
  - Load balancers and Elastic IPs
  - EC2 instances and Auto Scaling
  - IAM roles

---

## 🚀 Deployment

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd <your-repo-directory>
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Apply the Terraform plan

```bash
terraform apply
```

Confirm when prompted.

---

## 🌐 Access Information

- **Network Load Balancer DNS Name**:

```bash
terraform output nlb_dns_name
```

- You can map a custom domain to the **Elastic IPs** associated with this NLB.

- **Auto Scaling Group Name**:

```bash
terraform output asg_name
```

---

## ⚙️ Configuration

### Variables (`variables.tf`)

| Variable         | Description                            | Default             |
|------------------|----------------------------------------|---------------------|
| `aws_region`     | AWS region to deploy resources          | `us-east-1`         |
| `proxy_class`    | EC2 instance type for proxy             | `t3.micro`          |
| `upstream_ip`    | Destination IP for proxied TLS traffic  | `104.16.184.241`    |
| `upstream_port`  | Port for upstream TLS traffic           | `443`               |
| `vpc_cidr`       | CIDR for the VPC                        | `10.0.0.0/16`       |
| `subnet1_cidr`   | CIDR for public subnet 1                | `10.0.1.0/24`       |
| `subnet2_cidr`   | CIDR for public subnet 2                | `10.0.2.0/24`       |

You can override these by passing `-var` arguments or using a `terraform.tfvars` file.

---

## 🩺 Health Checks

- HAProxy listens on **port 9000** for TCP health checks.
- The NLB probes this port to verify instance health.
- Only traffic from within the VPC (`10.0.0.0/16`) is accepted for health checks.

---

## 🔐 Security

- The EC2 instances are only accessible on:
  - Port **443** from the internet
  - Port **9000** from inside the VPC
- **SSH is not enabled** — access is granted via **AWS Systems Manager (SSM)**.

---

## 🧼 Logging

- HAProxy logs to `/var/log/haproxy.log`
- Logs are rotated **daily**
- Retention: **7 compressed logs**
- Logging is handled by `rsyslog` and `logrotate` (installed via `user_data`)

---

## 🧯 Cleanup

To remove all resources:

```bash
terraform destroy
```

---

## 📘 Notes

- This setup performs **TLS passthrough**, meaning AWS and HAProxy do not decrypt TLS traffic.
- If you need to inspect or route by hostnames or headers, consider terminating TLS in HAProxy and using HTTP mode.

---

## 📎 Credits

This infrastructure is designed for low-cost, scalable, and observable TLS passthrough reverse proxying using AWS primitives and open-source tooling.
