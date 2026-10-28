#!/usr/bin/env bash
# =============================================================================
# extend-deploy-role.sh - add Week 2 network permissions to the deploy role
# Project : Onward Logistics - Secure Network for the Order System
#
# Adds one customer managed policy, onward-cfn-network-policy, to the existing
# onward-cfn-deploy-role (created in Week 1 by create-deploy-role.sh), so the
# same role can deploy templates/network-template.yaml through GitSync.
# No inline policies. Safe to run more than once.
#
# Run it in AWS CloudShell (credentials and the AWS CLI are already set up):
#   bash extend-deploy-role.sh
# =============================================================================

# Strict mode: stop on any error (-e), on an unset variable (-u),
# and when any command in a pipe fails (pipefail).
set -euo pipefail

# Means: names used below; change them here only.
# AWS uses: the existing Week 1 role and a new policy name.
ROLE_NAME="onward-cfn-deploy-role"
POLICY_NAME="onward-cfn-network-policy"
# Means: the current account ID, read at run time so none is hard-coded in the repo.
# AWS uses: the 12-digit ID returned by sts get-caller-identity.
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
# Temporary folder for the JSON file. The trap deletes it when the script exits.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Account : ${ACCOUNT_ID}"
echo "Role    : ${ROLE_NAME}"
echo "Policy  : ${POLICY_NAME}"

# The Week 1 script must have created the role first.
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Role ${ROLE_NAME} not found. Run week-1-secure-onboarding/scripts/create-deploy-role.sh first." >&2
  exit 1
fi

# ------------- permissions: only what network-template.yaml needs ------------
# Network policy: WHAT CloudFormation may do when it builds the Week 2 stack.
#   Ec2Network          - VPC, subnets, gateways, Elastic IPs, NAT, routes, S3 endpoint,
#                         security groups, launch templates and tags.
#   ReadAmiParameter    - read the public Amazon Linux AMI ID from SSM Parameter Store.
#   LoadBalancer        - create and manage the ALB, target group and listener.
#   AutoScaling         - create and manage the two Auto Scaling groups.
#   ServerRole          - manage only the onward-*-ec2-ssm-role and its instance profile.
#   ServerRolePolicy    - attach only AmazonSSMManagedInstanceCore to that role.
#   PassServerRole      - hand that role to EC2 and nothing else.
#   ServiceLinkedRoles  - let Auto Scaling and Elastic Load Balancing create their own
#                         service-linked roles the first time they are used.
#   Budget              - create and manage only onward-* budgets.
cat > "${WORK_DIR}/network-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Ec2Network",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
        "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DisassociateAddress",
        "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
        "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
        "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
        "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
        "ec2:CreateVpcEndpoint", "ec2:DeleteVpcEndpoints", "ec2:ModifyVpcEndpoint",
        "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
        "ec2:CreateLaunchTemplate", "ec2:CreateLaunchTemplateVersion",
        "ec2:DeleteLaunchTemplate", "ec2:DeleteLaunchTemplateVersions",
        "ec2:ModifyLaunchTemplate", "ec2:GetLaunchTemplateData",
        "ec2:RunInstances", "ec2:TerminateInstances",
        "ec2:CreateTags", "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ReadAmiParameter",
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": "arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"
    },
    {
      "Sid": "LoadBalancer",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScaling",
      "Effect": "Allow",
      "Action": [
        "autoscaling:Describe*",
        "autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup", "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "autoscaling:SuspendProcesses", "autoscaling:ResumeProcesses",
        "autoscaling:AttachLoadBalancerTargetGroups", "autoscaling:DetachLoadBalancerTargetGroups",
        "autoscaling:CreateOrUpdateTags", "autoscaling:DeleteTags"
      ],
      "Resource": "*"
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

# ------------------- create or update the policy, then attach ----------------
# Same pattern as Week 1: create on first run, otherwise publish a new default version.
if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  echo "Policy exists - publishing a new default version"
  # IAM keeps at most 5 versions: remove the oldest non-default one if full.
  versions="$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
    --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)"
  if [[ "$(wc -w <<< "$versions")" -ge 4 ]]; then
    oldest="$(tr '\t' '\n' <<< "$versions" | sort -V | head -1)"
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$oldest"
  fi
  aws iam create-policy-version --policy-arn "$POLICY_ARN" \
    --policy-document "file://${WORK_DIR}/network-policy.json" --set-as-default >/dev/null
else
  echo "Creating policy"
  aws iam create-policy --policy-name "$POLICY_NAME" \
    --description "Onward Week 2 network stack deployment" \
    --policy-document "file://${WORK_DIR}/network-policy.json" \
    --tags Key=Project,Value=onward Key=Environment,Value=dev \
    >/dev/null
fi
# Attaching twice is harmless.
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"

echo
echo "Done. Policies now attached to ${ROLE_NAME}:"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
  --query 'AttachedPolicies[].PolicyName' --output text
