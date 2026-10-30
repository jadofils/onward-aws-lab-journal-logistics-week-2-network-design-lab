# Week 2 IAM Policies

Policy documents for `onward-cfn-network-deploy-role`, the role GitSync and CloudFormation use for the `onward-aws-lab-journal-week-2` stack. The role is created in the IAM console; these files are what you paste in. Replace every `<ACCOUNT_ID>` with your 12-digit account ID in the console only, never in this repository.

| File | Used as | What it allows |
|------|---------|----------------|
| [trust-policy.json](trust-policy.json) | Role trust policy | Only CloudFormation and the Git sync service, only from this account |
| [deploy-policy.json](deploy-policy.json) | Customer managed policy `onward-cfn-network-deploy-policy` | Create the network, servers, load balancer and budget; change or delete only resources tagged `Project=onward` |
| [gitsync-policy.json](gitsync-policy.json) | Customer managed policy `onward-cfn-network-gitsync-policy` | Run change sets on this stack only, and pass this role only to CloudFormation |

Each policy is a separate managed policy because IAM limits one managed policy to 6,144 characters. The deploy policy uses about 4,700, so splitting keeps room to grow.

## Create the role in the console

1. **IAM → Policies → Create policy → JSON.** Paste `deploy-policy.json`, replace `<ACCOUNT_ID>`, name it `onward-cfn-network-deploy-policy`, add tags `Project=onward`, `Environment=dev`, `ApprovedBy=head-of-security`.
2. Repeat with `gitsync-policy.json`, named `onward-cfn-network-gitsync-policy`.
3. **IAM → Roles → Create role → Custom trust policy.** Paste `trust-policy.json` and replace `<ACCOUNT_ID>`.
4. Attach the two policies from steps 1 and 2. Add no inline policies.
5. Name the role `onward-cfn-network-deploy-role`, add the same three tags, and create it.
6. In CloudFormation, select this role as both the Git sync IAM role and the stack's IAM role.

To remove it: detach both policies, delete the role, then delete the two policies.
