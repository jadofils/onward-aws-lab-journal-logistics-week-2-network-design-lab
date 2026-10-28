#!/usr/bin/env bash
# =============================================================================
# create-network-deploy-role.sh - CloudFormation role for the Week 2 network
# Project : Onward Logistics - Secure Network for the Order System
#
# Creates (or updates) onward-cfn-network-deploy-role, used for both GitSync
# fields of the onward-dev-network stack:
#   - Git sync IAM role   (trusted by cloudformation.sync.codeconnections)
#   - Stack service role  (trusted by cloudformation, creates the resources)
# It is separate from Week 1's onward-cfn-deploy-role, so neither stack can
# touch the other's resources. All permissions live in customer managed
# policies (no inline policies). Safe to run more than once.
#
# Run it in AWS CloudShell:
#   bash create-network-deploy-role.sh
# Remove everything it created:
#   bash create-network-deploy-role.sh --delete
# =============================================================================

# Strict mode: stop on any error (-e), on an unset variable (-u),
# and when any command in a pipe fails (pipefail).
set -euo pipefail

# Means: names and tags used below; change them here only.
# AWS uses: these names for the role and its two customer managed policies.
ROLE_NAME="onward-cfn-network-deploy-role"
DEPLOY_POLICY_NAME="onward-cfn-network-deploy-policy"
GITSYNC_POLICY_NAME="onward-cfn-network-gitsync-policy"
# Means: the GitSync stack this role may run change sets on.
# AWS uses: onward-aws-lab-journal-week-2 unless STACK_NAME is set before running the script.
STACK_NAME="${STACK_NAME:-onward-aws-lab-journal-week-2}"
# Means: who approved this access; recorded as a tag (company rule).
# AWS uses: head-of-security unless APPROVED_BY is set before running the script.
APPROVED_BY="${APPROVED_BY:-head-of-security}"
# Means: the current account ID, read at run time so none is hard-coded in the repo.
# AWS uses: the 12-digit ID returned by sts get-caller-identity.
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TAGS=(Key=Project,Value=onward Key=Environment,Value=dev
      Key=ApprovedBy,Value="${APPROVED_BY}" Key=ManagedBy,Value=create-network-deploy-role.sh)
# Temporary folder for the JSON policy files. The trap deletes it when the script exits.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ------------------------------ --delete -------------------------------------
# Undo: detach and delete both policies (all versions), then delete the role.
if [[ "${1:-}" == "--delete" ]]; then
  for name in "$DEPLOY_POLICY_NAME" "$GITSYNC_POLICY_NAME"; do
    arn="arn:aws:iam::${ACCOUNT_ID}:policy/${name}"
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$arn" 2>/dev/null || true
    for v in $(aws iam list-policy-versions --policy-arn "$arn" \
        --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null); do
      aws iam delete-policy-version --policy-arn "$arn" --version-id "$v"
    done
    aws iam delete-policy --policy-arn "$arn" 2>/dev/null && echo "Deleted policy ${name}" || true
  done
  aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null && echo "Deleted role ${ROLE_NAME}" || true
  exit 0
fi

echo "Role        : ${ROLE_NAME}"
echo "Policies    : ${DEPLOY_POLICY_NAME}, ${GITSYNC_POLICY_NAME}"
echo "ApprovedBy  : ${APPROVED_BY}"
echo "Stack       : ${STACK_NAME}"

# ------------------------- trust: CloudFormation only ------------------------
# Trust policy: WHO may assume the role. Only CloudFormation and the Git sync
# service, and only for requests from this account (aws:SourceAccount).
cat > "${WORK_DIR}/trust.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "cloudformation.amazonaws.com",
          "cloudformation.sync.codeconnections.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "aws:SourceAccount": "${ACCOUNT_ID}" } }
    }
  ]
}
EOF

# ----------- permissions: only what templates/network-template.yaml needs ----
# Deploy policy: WHAT CloudFormation may do when it builds the stack.
#   Ec2Read             - look up VPCs, subnets, images and so on (read only).
#   Ec2Create           - create and configure network pieces and launch templates.
#                         Creating cannot harm existing resources.
#   Ec2ChangeOnlyOnward - delete, detach, revoke or re-route ONLY resources tagged
#                         Project=onward (the stack tags put it on everything it creates).
#   Ec2LaunchTemplates  - delete launch templates (only onward-* ones exist).
#   Ec2RunServers       - launch servers from a launch template (checked when the
#                         Auto Scaling group is created). No TerminateInstances:
#                         Auto Scaling removes servers with its own service role.
#   ReadAmiParameter    - read the public Amazon Linux image ID from SSM.
#   LoadBalancerCreate  - create and read the load balancer, target group and listener.
#   LoadBalancerChange  - delete them ONLY when tagged Project=onward.
#   AutoScalingCreate   - create and read Auto Scaling groups.
#   AutoScalingChange   - update or delete ONLY groups tagged Project=onward.
#   ServerRole          - manage only onward-*-ec2-ssm-role and its instance profile.
#   ServerRolePolicy    - attach only AmazonSSMManagedInstanceCore to that role.
#   PassServerRole      - hand that role to EC2 and nothing else.
#   ServiceLinkedRoles  - let Auto Scaling and Elastic Load Balancing create their
#                         own service roles the first time they are used.
#   Budget              - manage only onward-* budgets.
cat > "${WORK_DIR}/deploy-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Ec2Read",
      "Effect": "Allow",
      "Action": ["ec2:Describe*", "ec2:GetLaunchTemplateData"],
      "Resource": "*"
    },
    {
      "Sid": "Ec2Create",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc", "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet", "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway", "ec2:AttachInternetGateway",
        "ec2:AllocateAddress", "ec2:CreateNatGateway",
        "ec2:CreateRouteTable", "ec2:CreateRoute", "ec2:AssociateRouteTable",
        "ec2:CreateVpcEndpoint", "ec2:ModifyVpcEndpoint",
        "ec2:CreateSecurityGroup", "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:CreateLaunchTemplate", "ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Ec2ChangeOnlyOnward",
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVpc", "ec2:DeleteSubnet",
        "ec2:DetachInternetGateway", "ec2:DeleteInternetGateway",
        "ec2:ReleaseAddress", "ec2:DisassociateAddress", "ec2:DeleteNatGateway",
        "ec2:DeleteRouteTable", "ec2:DeleteRoute", "ec2:ReplaceRoute", "ec2:DisassociateRouteTable",
        "ec2:DeleteSecurityGroup", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
        "ec2:DeleteTags"
      ],
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:ResourceTag/Project": "onward" } }
    },
    {
      "Sid": "Ec2LaunchTemplates",
      "Effect": "Allow",
      "Action": ["ec2:DeleteLaunchTemplate", "ec2:DeleteLaunchTemplateVersions", "ec2:DeleteVpcEndpoints"],
      "Resource": "*"
    },
    {
      "Sid": "Ec2RunServers",
      "Effect": "Allow",
      "Action": "ec2:RunInstances",
      "Resource": "*"
    },
    {
      "Sid": "ReadAmiParameter",
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": "arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"
    },
    {
      "Sid": "LoadBalancerCreate",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:CreateListener", "elasticloadbalancing:AddTags",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LoadBalancerChange",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DeleteListener", "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:ResourceTag/Project": "onward" } }
    },
    {
      "Sid": "AutoScalingCreate",
      "Effect": "Allow",
      "Action": [
        "autoscaling:Describe*", "autoscaling:CreateAutoScalingGroup", "autoscaling:CreateOrUpdateTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScalingChange",
      "Effect": "Allow",
      "Action": [
        "autoscaling:UpdateAutoScalingGroup", "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup",
        "autoscaling:SuspendProcesses", "autoscaling:ResumeProcesses",
        "autoscaling:AttachLoadBalancerTargetGroups", "autoscaling:DetachLoadBalancerTargetGroups",
        "autoscaling:DeleteTags"
      ],
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:ResourceTag/Project": "onward" } }
    },
    {
      "Sid": "ServerRole",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateAssumeRolePolicy",
        "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
        "iam:ListAttachedRolePolicies", "iam:ListRolePolicies", "iam:ListInstanceProfilesForRole",
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile", "iam:UntagInstanceProfile"
      ],
      "Resource": [
        "arn:aws:iam::${ACCOUNT_ID}:role/onward-*-ec2-ssm-role",
        "arn:aws:iam::${ACCOUNT_ID}:instance-profile/onward-*-ec2-ssm-profile"
      ]
    },
    {
      "Sid": "ServerRolePolicy",
      "Effect": "Allow",
      "Action": ["iam:AttachRolePolicy", "iam:DetachRolePolicy"],
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/onward-*-ec2-ssm-role",
      "Condition": { "ArnEquals": { "iam:PolicyARN": "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" } }
    },
    {
      "Sid": "PassServerRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/onward-*-ec2-ssm-role",
      "Condition": { "StringEquals": { "iam:PassedToService": "ec2.amazonaws.com" } }
    },
    {
      "Sid": "ServiceLinkedRoles",
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": { "StringEquals": { "iam:AWSServiceName": [
        "autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com"
      ] } }
    },
    {
      "Sid": "Budget",
      "Effect": "Allow",
      "Action": [
        "budgets:ViewBudget", "budgets:ModifyBudget",
        "budgets:TagResource", "budgets:UntagResource", "budgets:ListTagsForResource"
      ],
      "Resource": "arn:aws:budgets::${ACCOUNT_ID}:budget/onward-*"
    }
  ]
}
EOF

# ------- Git sync: read the repo, run change sets, watch for new commits -----
# Same as Week 1, except change sets are limited to STACK_NAME (and onward-*-network)
# and the role can only pass ITSELF to CloudFormation.
cat > "${WORK_DIR}/gitsync-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SyncToCloudFormation",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateChangeSet", "cloudformation:DeleteChangeSet",
        "cloudformation:DescribeChangeSet", "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStacks", "cloudformation:ExecuteChangeSet",
        "cloudformation:GetTemplate", "cloudformation:ListChangeSets"
      ],
      "Resource": [
        "arn:aws:cloudformation:*:${ACCOUNT_ID}:stack/${STACK_NAME}/*",
        "arn:aws:cloudformation:*:${ACCOUNT_ID}:stack/onward-*-network/*"
      ]
    },
    {
      "Sid": "ListAndValidate",
      "Effect": "Allow",
      "Action": ["cloudformation:ListStacks", "cloudformation:ValidateTemplate"],
      "Resource": "*"
    },
    {
      "Sid": "PolicyForManagedRules",
      "Effect": "Allow",
      "Action": ["events:PutRule", "events:PutTargets"],
      "Resource": "*",
      "Condition": { "StringEquals": { "events:ManagedBy": "cloudformation.sync.codeconnections.amazonaws.com" } }
    },
    {
      "Sid": "PolicyForDescribingRule",
      "Effect": "Allow",
      "Action": "events:DescribeRule",
      "Resource": "*"
    },
    {
      "Sid": "PassThisRoleToCloudFormation",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}",
      "Condition": { "StringEquals": { "iam:PassedToService": "cloudformation.amazonaws.com" } }
    }
  ]
}
EOF

# upsert_policy <name> <document> -> creates the managed policy or publishes a new default version,
# then attaches it to the role. Same pattern as Week 1, so the script is safe to re-run.
upsert_policy() {
  local arn="arn:aws:iam::${ACCOUNT_ID}:policy/$1"
  if aws iam get-policy --policy-arn "$arn" >/dev/null 2>&1; then
    echo "Policy $1 exists - publishing a new default version"
    local versions oldest
    versions="$(aws iam list-policy-versions --policy-arn "$arn" \
      --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)"
    # IAM keeps at most 5 versions: remove the oldest non-default one if full.
    if [[ "$(wc -w <<< "$versions")" -ge 4 ]]; then
      oldest="$(tr '\t' '\n' <<< "$versions" | sort -V | head -1)"
      aws iam delete-policy-version --policy-arn "$arn" --version-id "$oldest"
    fi
    aws iam create-policy-version --policy-arn "$arn" \
      --policy-document "file://$2" --set-as-default >/dev/null
  else
    echo "Creating policy $1"
    aws iam create-policy --policy-name "$1" \
      --description "Onward Week 2 network stack deployment ($1)" \
      --policy-document "file://$2" --tags "${TAGS[@]}" >/dev/null
  fi
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$arn"
}

# ---------------------------------- role -------------------------------------
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Role exists - updating trust policy and tags"
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" \
    --policy-document "file://${WORK_DIR}/trust.json"
  aws iam tag-role --role-name "$ROLE_NAME" --tags "${TAGS[@]}"
else
  echo "Creating role"
  aws iam create-role --role-name "$ROLE_NAME" \
    --description "CloudFormation service role for the onward-dev-network stack" \
    --assume-role-policy-document "file://${WORK_DIR}/trust.json" \
    --tags "${TAGS[@]}" >/dev/null
fi

# -------------------------------- policies -----------------------------------
upsert_policy "$DEPLOY_POLICY_NAME" "${WORK_DIR}/deploy-policy.json"
upsert_policy "$GITSYNC_POLICY_NAME" "${WORK_DIR}/gitsync-policy.json"

echo
echo "Done. Policies attached to ${ROLE_NAME}:"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
  --query 'AttachedPolicies[].PolicyName' --output text
echo "Select '${ROLE_NAME}' as the Git sync IAM role and as the stack's IAM role."
