# Week 2 Templates

CloudFormation template for the Week 2 network, drawn in [../docs/images/01-architecture.png](../docs/images/01-architecture.png).

| File | What it builds |
|------|----------------|
| [network-template.yaml](network-template.yaml) | The whole order-system network: VPC, 6 subnets in 2 zones, internet gateway, NAT gateways, route tables, S3 gateway endpoint, 3 security groups, server IAM role, load balancer, 2 Auto Scaling groups and a budget |

## How the template meets the brief

| Requirement | Where in the template |
|-------------|-----------------------|
| Front end reachable, survives losing one zone | `WebLoadBalancer` in both public subnets; `WebAutoScalingGroup` (min 2) across `WebSubnetA` and `WebSubnetB`; `HealthCheckType: ELB` |
| Internal servers unreachable from the internet | Servers only in private subnets with no public IP; private route tables have no route to the internet gateway; `OrderSecurityGroup` allows 8080 from `WebSecurityGroup` only |
| Internal servers can download updates | `PrivateDefaultRouteA` and `PrivateDefaultRouteB` to a NAT gateway in the same zone; `S3GatewayEndpoint` for Amazon Linux repos |
| Admin with no open ports and no shared keys | `InstanceRole` with AWS managed `AmazonSSMManagedInstanceCore`; no key pair; no security group allows port 22 |
| Free Tier Amazon Linux, page with name and lab | `LatestAmiId` (Amazon Linux 2023), `InstanceType` t3.micro or t2.micro; `WebLaunchTemplate` UserData writes the page |
| Naming and tags | Every name is `onward-<Environment>-<purpose>`; `Project`, `Owner`, `Environment` come from the stack tags in [../deployment.yaml](../deployment.yaml) |
| No inline policies | No `AWS::IAM::Policy` and no `Policies:` property; only `ManagedPolicyArns` |
| Cost visible to Finance | `NetworkBudget` with alerts at 80% actual and 100% forecast |

## Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `Environment` | `dev` | Name part: `onward-dev-...` |
| `OwnerName` | `Jado Fils SEZIKEYE` | Shown on the front-end page |
| `LabName` | the lab title | Shown on the front-end page |
| `InstanceType` | `t3.micro` | Must be Free Tier eligible in your account |
| `LatestAmiId` | AL2023 SSM parameter | Latest Amazon Linux 2023 image, looked up at deploy time |
| `NatGatewayMode` | `one-per-az` | `single` saves about $33 a month but loses resilience |
| `MonthlyBudgetUsd` | `120` | Budget limit |
| `BudgetAlertEmail` | empty | Set it to receive budget emails |

## Validate before a PR

```bash
cfn-lint week-2-secure-network/templates/network-template.yaml
aws cloudformation validate-template --template-body file://week-2-secure-network/templates/network-template.yaml
```

Check which instance types are Free Tier eligible in your account (read-only):

```bash
aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true \
  --query "InstanceTypes[].InstanceType" --output text
```
