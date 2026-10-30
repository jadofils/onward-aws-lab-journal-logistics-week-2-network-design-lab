# Week 2 Scripts

Evidence script for Week 2. It runs in AWS CloudShell, like Week 1's ([onward-aws-lab-journal](https://github.com/jadofils/onward-aws-lab-journal/tree/main/week-1-secure-onboarding/scripts)).

| Script | Purpose | Changes AWS? |
|--------|---------|--------------|
| [evidence.sh](evidence.sh) | Runs every client check against the live stack and saves a report in `evidence-<timestamp>/` (gitignored). `-p` adds the package download test | No, unless `-p` (installs htop on one order server) |

## Run order

1. In the IAM console, create the role `onward-cfn-network-deploy-role` from the policy files in [../iam/](../iam/README.md), following the steps there.
2. Create the GitSync stack `onward-aws-lab-journal-week-2` with deployment file `network-template-deployment.yaml`, and select `onward-cfn-network-deploy-role` as both the Git sync IAM role and the stack's IAM role.
3. After the stack deploys, run `bash evidence.sh` in CloudShell.

## What the deploy role can do

Created in the IAM console from [../iam/](../iam/README.md), separate from Week 1's role, with customer managed policies only (no inline policies).

Trust: only CloudFormation (`cloudformation.amazonaws.com`) and the Git sync service (`cloudformation.sync.codeconnections.amazonaws.com`), only from this account.

| Statement | Scope |
|-----------|-------|
| `Ec2Read`, `ReadAmiParameter` | Read only; the AMI lookup is limited to the public Amazon Linux parameters |
| `Ec2Create`, `LoadBalancerCreate`, `AutoScalingCreate` | Create network pieces, launch templates, the load balancer and Auto Scaling groups. Creating cannot harm existing resources |
| `Ec2ChangeOnlyOnward`, `LoadBalancerChange`, `AutoScalingChange` | Delete, detach, revoke, re-route or update **only resources tagged `Project=onward`**. The stack tags put that tag on everything the template creates |
| `Ec2LaunchTemplates` | Delete launch templates and VPC endpoints (no tag condition; see below) |
| `Ec2RunServers` | `ec2:RunInstances`, checked when an Auto Scaling group is created. There is **no** `ec2:TerminateInstances`: Auto Scaling removes servers with its own service role |
| `ServerRole`, `ServerRolePolicy`, `PassServerRole` | Only `onward-*-ec2-ssm-role` and its instance profile; it can attach only `AmazonSSMManagedInstanceCore` and pass the role only to EC2 |
| `ServiceLinkedRoles` | Only the Auto Scaling and Elastic Load Balancing service-linked roles |
| `Budget` | Only `onward-*` budgets |
| Git sync policy | Change sets only on the `onward-aws-lab-journal-week-2` stack and `onward-*-network` stacks; pass only this role, only to CloudFormation |

## Known limits (check during the first deploy and delete)

- Tag conditions rely on CloudFormation copying the stack tag `Project=onward` onto each resource. If a resource type does not receive it, deleting the stack fails with "not authorized" on that resource; the error names the action to fix.
- Launch template and VPC endpoint deletes have no tag condition, because it is not certain these resources receive stack tags.
- Test it once: deploy, update, then delete the stack, and read the events for any `AccessDenied`.
