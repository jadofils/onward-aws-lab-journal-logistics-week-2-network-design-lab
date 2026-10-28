# Onward Logistics: Secure Network for the Order System

Week 2 lab: a highly available, secure network for the Onward Logistics order system, provisioned with AWS CloudFormation and deployed through CloudFormation GitSync.

**Module:** Network & Security on AWS · **Week:** 2 · **Status:** Discovery

Full brief: [docs/lab-brief.md](docs/lab-brief.md)

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
- [ ] **Template and deployment file:** `templates/` and `deployment.yaml` in this folder
- [ ] **GitSync stack** using deployment file path `week-2-secure-network/deployment.yaml`
- [ ] **Evidence:** scripts and screenshots proving each client check
- [ ] **Architecture diagram** of the resources inside the VPC (optional)
- [ ] **Live code review:** walk through the code, demonstrate the client's checks, defend the reasoning

## Folder layout

```
week-2-secure-network/
├── README.md            # This file
├── deployment.yaml      # GitSync deployment file (to be added)
├── docs/
│   ├── lab-brief.md     # Lab brief and client requirements
│   └── discovery.md     # Discovery report (committed first)
├── templates/           # CloudFormation templates (to be added)
└── scripts/             # Helper and evidence scripts (to be added)
```

## Open questions

- The brief asks for the discovery report at `docs/discovery.md`. In this repository it lives at `week-2-secure-network/docs/discovery.md`; check with the instructor that this is acceptable.
- Naming and tagging follow the [Client Profile](../docs/client-profile.md): `onward-dev-<purpose>`, tags `Project=onward`, `Owner`, `Environment`.
