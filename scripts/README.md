# Week 2 Scripts

Helper and evidence scripts for Week 2. They run in AWS CloudShell, like Week 1's ([../../week-1-secure-onboarding/scripts/](../../week-1-secure-onboarding/scripts/)).

| Script | Purpose | Changes AWS? |
|--------|---------|--------------|
| [extend-deploy-role.sh](extend-deploy-role.sh) | Adds `onward-cfn-network-policy` to the existing `onward-cfn-deploy-role`, so the same role can deploy the Week 2 network through GitSync | Yes: creates or updates one IAM policy and attaches it |

## Run order

1. Week 1's `create-deploy-role.sh` must already have created `onward-cfn-deploy-role`.
2. Upload `extend-deploy-role.sh` to CloudShell and run `bash extend-deploy-role.sh`.
3. Create the GitSync stack `onward-dev-network` with deployment file `week-2-secure-network/deployment.yaml`.

## What the new policy allows

| Statement | Scope |
|-----------|-------|
| `Ec2Network` | VPC, subnets, gateways, Elastic IPs, NAT, routes, S3 endpoint, security groups, launch templates, tags |
| `ReadAmiParameter` | Only the public Amazon Linux AMI parameters |
| `LoadBalancer`, `AutoScaling` | The load balancer, target group, listener and Auto Scaling groups |
| `ServerRole`, `ServerRolePolicy` | Only `onward-*-ec2-ssm-role`, and it can attach only `AmazonSSMManagedInstanceCore` |
| `PassServerRole` | Pass that role to EC2 only |
| `ServiceLinkedRoles` | Only the Auto Scaling and Elastic Load Balancing service-linked roles |
| `Budget` | Only `onward-*` budgets |

## Planned

| Script | Purpose |
|--------|---------|
| Evidence script | Proves the client's checks: front end reachable, internal servers unreachable from the internet, package download works, admin access without open ports |
