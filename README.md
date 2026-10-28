# Onward Logistics: Secure Network for the Order System

Week 2 lab: a highly available, secure network for the Onward Logistics order system, provisioned with AWS CloudFormation and deployed through CloudFormation GitSync.

**Module:** Network & Security on AWS · **Week:** 2 · **Status:** Deployed (28 October 2026), checks passing, see [Deployment evidence](#deployment-evidence)

Full brief: [docs/lab-brief.md](docs/lab-brief.md) · Client background: [docs/client-profile.md](docs/client-profile.md) · Week 1 lab: [onward-aws-lab-journal](https://github.com/jadofils/onward-aws-lab-journal)

## Client objectives

| # | Objective | Asked by |
|---|-----------|----------|
| 1 | Front end reachable from the internet, and still working if one Availability Zone is lost | Chief Technology Officer |
| 2 | Internal order services unreachable from the internet, but able to download updates | Head of Security, Head of Operations |
| 3 | Engineers administer every server with no open admin ports and no shared keys | Head of Security, Head of Operations |
| 4 | Show what the network costs, and justify the choices on cost and resilience | Finance Lead |
| 5 | Prove every objective to the Head of Security and the Finance Lead | All |

## Mandatory requirements

- Everything provisioned with AWS CloudFormation; nothing created in the console
- Deployed with CloudFormation GitSync from this repository
- Highly available, and strictly matching the Head of Security's requirements
- Free Tier eligible Amazon Linux servers; each front-end server shows a preinstalled page with your full name and the lab name
- Internal servers administered remotely without inbound SSH ports
- Company naming and tagging standards from the Client Profile
- No inline policies anywhere in the template

## Stages and deliverables

- [x] **Discovery report:** [docs/discovery.md](docs/discovery.md), committed **before** any template, so the Git history shows the thinking came first (fill in your name, then review)
- [x] **Template and deployment file:** [templates/network-template.yaml](templates/network-template.yaml) and [network-template-deployment.yaml](network-template-deployment.yaml)
- [x] **GitSync stack** `onward-aws-lab-journal-week-2` using deployment file path `network-template-deployment.yaml`
- [x] **Evidence:** all 7 client checks recorded in [Deployment evidence](#deployment-evidence); evidence script to come
- [x] **Architecture diagram** of the resources inside the VPC (optional): see [Solution architecture](#solution-architecture)
- [ ] **Live code review:** walk through the code, demonstrate the client's checks, defend the reasoning

## Deployment evidence

Stack `onward-aws-lab-journal-week-2` in eu-west-1, deployed by GitSync from `main`. Checks run in CloudShell (read-only) on 28 October 2026. Account details are left out.

| # | Client check | Result | Status |
|---|--------------|--------|--------|
| 1 | Stack deployed | `UPDATE_COMPLETE`; front end at `http://onward-dev-web-alb-1832706538.eu-west-1.elb.amazonaws.com` | ✅ |
| 2 | Front end reachable, served from both zones | 6 requests answered by `i-03af88313238a5761` (eu-west-1a) and `i-0d07da81920faed9e` (eu-west-1b) | ✅ |
| 3 | Servers are private, one of each per zone | 4 servers, none with a public IP (table below) | ✅ |
| 4 | Engineers can administer every server without open ports | All 4 servers `Online` in Session Manager | ✅ |
| 5 | No admin ports open | Inbound rules: alb-sg 80, web-sg 80, order-sg 8080; no port 22 | ✅ |
| 6 | Internal server can download a package | Session Manager session on `i-0e68984f1228eb301` (order, eu-west-1a): `sudo dnf install -y htop` installed `htop-3.2.1` (183 kB) from the `amazonlinux` repo; `curl localhost:8080` returned "Onward order service (dev): OK" | ✅ |
| 7 | No one on the internet can reach an internal server | From CloudShell (outside the VPC), `curl -m 5 http://10.20.20.46:8080` timed out after 5 s (run twice). Blocked by: no public IP, no inbound route, and order-sg allows 8080 from web-sg only | ✅ |

| Server | Instance | Zone | Private IP | Public IP |
|--------|----------|------|------------|-----------|
| onward-dev-web | i-03af88313238a5761 | eu-west-1a | 10.20.10.206 | None |
| onward-dev-web | i-0d07da81920faed9e | eu-west-1b | 10.20.11.198 | None |
| onward-dev-order | i-0e68984f1228eb301 | eu-west-1a | 10.20.20.46 | None |
| onward-dev-order | i-0c009f763ba37559c | eu-west-1b | 10.20.21.144 | None |

Each private IP falls in the planned subnet: web 10.20.10.0/24 and 10.20.11.0/24, order 10.20.20.0/24 and 10.20.21.0/24. Instance IDs and the load balancer address change each time the stack is rebuilt.

## Solution architecture

The planned design, drawn before the build. Source: [docs/architecture.drawio](docs/architecture.drawio) · [open in draw.io](https://app.diagrams.net/#Hjadofils%2Fonward-aws-lab-journal-logistics-week-2-network-design-lab%2Fmain%2Fdocs%2Farchitecture.drawio)

![Week 2 architecture: an Application Load Balancer in two public subnets sends traffic to web servers in private subnets in two Availability Zones; order servers sit in a second private tier; each zone has its own NAT gateway for outbound updates; engineers reach servers through Session Manager with no open ports](docs/images/01-architecture.png)

| Layer | Zone A | Zone B | Reachable from |
|-------|--------|--------|----------------|
| Public subnets | 10.20.0.0/24: ALB node, NAT gateway A | 10.20.1.0/24: ALB node, NAT gateway B | The internet (ALB only, port 80) |
| Private web subnets | 10.20.10.0/24: web server A | 10.20.11.0/24: web server B | The ALB only (port 80) |
| Private order subnets | 10.20.20.0/24: order server A | 10.20.21.0/24: order server B | The web servers only (port 8080) |

No security group allows port 22. Engineers use Session Manager, and every server has the managed policy `AmazonSSMManagedInstanceCore` through an instance profile.

### Who can talk to whom

![Four traffic rows: customer request, software update through NAT, engineer admin through Session Manager, and an attack from the internet blocked by three layers](docs/images/02-traffic-and-security-groups.png)

### When a zone fails

![Zone A fails, health checks fail, the load balancer moves traffic to zone B, Auto Scaling replaces the server, zone B keeps getting updates through its own NAT gateway](docs/images/03-zone-failure.png)

### What it costs

![Monthly cost: about $103 before EC2 and data, with the alternatives rejected on cost or risk](docs/images/04-monthly-cost.png)

## Folder layout

```
onward-aws-lab-journal-logistics-week-2-network-design-lab/
├── README.md            # This file
├── .gitignore           # Keeps evidence output, .env and keys out of Git
├── network-template-deployment.yaml  # GitSync deployment file (stack onward-aws-lab-journal-week-2)
├── docs/
│   ├── lab-brief.md     # Lab brief and client requirements
│   ├── client-profile.md    # Onward Logistics profile, stakeholders and standards
│   ├── discovery-report-template.md  # Course template for the discovery report
│   ├── discovery.md     # Discovery report (committed first)
│   ├── Discovery Report.docx  # Same report in the course Word template
│   ├── architecture.drawio  # draw.io: architecture, traffic, zone failure, cost (4 pages)
│   └── images/          # PNG exports of each diagram page
├── templates/           # network-template.yaml
└── scripts/             # create-network-deploy-role.sh (evidence script to come)
```

## Company standards

- Naming and tagging follow the [Client Profile](docs/client-profile.md): `onward-dev-<purpose>`, tags `Project=onward`, `Owner`, `Environment`.
