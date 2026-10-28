# Week 2 Scripts

Helper and evidence scripts for Week 2. They run in AWS CloudShell, like Week 1's ([onward-aws-lab-journal](https://github.com/jadofils/onward-aws-lab-journal/tree/main/week-1-secure-onboarding/scripts)).

| Script | Purpose | Changes AWS? |
|--------|---------|--------------|
| [create-network-deploy-role.sh](create-network-deploy-role.sh) | Creates `onward-cfn-network-deploy-role`, the role GitSync and CloudFormation use for the `onward-aws-lab-journal-week-2` stack. Separate from Week 1's role. `--delete` removes it again | Yes: one IAM role and two customer managed policies |

## Run order

1. In CloudShell: `bash create-network-deploy-role.sh`
2. Create the GitSync stack `onward-aws-lab-journal-week-2` with deployment file `network-template-deployment.yaml`, and select `onward-cfn-network-deploy-role` as both the Git sync IAM role and the stack's IAM role.

To record a different approver: `APPROVED_BY="name-or-role" bash create-network-deploy-role.sh`

## What the role can do

Trust: only CloudFormation and the Git sync service, only from this account.

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
| Git sync policy | Change sets only on the `STACK_NAME` stack (default `onward-aws-lab-journal-week-2`) and `onward-*-network` stacks; pass only this role, only to CloudFormation |

## Known limits (check during the first deploy and delete)

- Tag conditions rely on CloudFormation copying the stack tag `Project=onward` onto each resource. If a resource type does not receive it, deleting the stack fails with "not authorized" on that resource; the error names the action to fix.
- Launch template and VPC endpoint deletes have no tag condition, because it is not certain these resources receive stack tags.
- Test it once: deploy, update, then delete the stack, and read the events for any `AccessDenied`.
