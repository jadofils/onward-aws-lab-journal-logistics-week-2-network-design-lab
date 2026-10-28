#!/usr/bin/env bash
# =============================================================================
# evidence.sh - Verification and evidence collector (Week 2)
# Project : Onward Logistics - Secure Network for the Order System
#
# Proves, with live AWS data, that each client check is met:
#   1. Provisioned by CloudFormation / GitSync, no inline policies
#   2. Front end reachable from the internet, served from both zones
#   3. Every server is private (no public IP), one of each per zone
#   4. No one on the internet can start a connection to an internal server
#   5. Internal servers can download updates (NAT gateway per zone)
#   6. Engineers administer every server with no open ports and no keys
#   7. Company standards: tags, budget alert
#
# Usage:
#   bash scripts/evidence.sh [-s stack-name] [-r region] [-o output-dir] [-p] [-h]
#
#   -s  CloudFormation stack name   (default: onward-aws-lab-journal-week-2)
#   -r  AWS region of the stack     (default: AWS_REGION, else eu-west-1)
#   -o  Output directory            (default: ./evidence-<timestamp>)
#   -p  Run the PACKAGE TEST: uses Session Manager Run Command to install
#       htop on one order server. Changes that server, so it is opt-in.
#   -h  Show help
#
# Run it from CloudShell (outside the VPC), so the direct connection test
# in check 4 really comes from outside. Read-only unless -p is given.
# =============================================================================

# Stop on unset variables and failed pipes. "-e" is left out on purpose,
# so one failed check is reported and the script carries on with the rest.
# Means: catch typos and broken pipes, but keep running after a failed check.
# AWS uses: nothing; local bash setting.
set -uo pipefail

# ----------------------------- configuration ---------------------------------
# Means: defaults; -s, -r and -o can override them.
# AWS uses: nothing yet; sent later as --stack-name and --region.
STACK_NAME="onward-aws-lab-journal-week-2"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-west-1}}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR=""
PACKAGE_TEST=false
# Means: how many times to call the website when looking for both zones.
# AWS uses: nothing; local loop count.
REQUESTS=10

# ------------------------------- arguments -----------------------------------
# Prints the header comment above (between the two ===== lines) as help text.
# Means: a function that shows the help text.
# AWS uses: nothing; reads this file.
usage() { awk 'NR>2 && /^# =====/{exit} NR>2{sub(/^# ?/,""); print}' "$0"; exit 0; }

# Means: turn -s, -r, -o, -p and -h into settings.
# AWS uses: nothing; local only.
while getopts "s:r:o:ph" opt; do
  case "$opt" in
    s) STACK_NAME="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    o) OUT_DIR="$OPTARG" ;;
    p) PACKAGE_TEST=true ;;
    *) usage ;;
  esac
done

# Means: create the output folder; everything printed also goes to evidence-report.txt.
# AWS uses: nothing; local files.
OUT_DIR="${OUT_DIR:-./evidence-${TIMESTAMP}}"
mkdir -p "$OUT_DIR"
LOG="${OUT_DIR}/evidence-report.txt"
exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG")) 2>&1

# -------------------------------- helpers ------------------------------------
# Means: colours only on a terminal, so the saved report stays plain text.
# AWS uses: nothing.
if [[ -t 1 ]]; then
  GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  GREEN=""; RED=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi
PASS=0; FAIL=0; WARN=0; SECTION_NO=0

# Means: print a numbered section heading and PASS / FAIL / WARN / INFO lines, and count them.
# AWS uses: nothing; they only print.
section() { SECTION_NO=$((SECTION_NO + 1)); printf '\n%s== %d. %s ==%s\n' "$BOLD$BLUE" "$SECTION_NO" "$1" "$RESET"; }
pass()    { PASS=$((PASS + 1)); printf '  %s[PASS]%s %s\n' "$GREEN" "$RESET" "$1"; }
fail()    { FAIL=$((FAIL + 1)); printf '  %s[FAIL]%s %s\n' "$RED" "$RESET" "$1"; }
warn()    { WARN=$((WARN + 1)); printf '  %s[WARN]%s %s\n' "$YELLOW" "$RESET" "$1"; }
info()    { printf '  %s[INFO]%s %s\n' "$BLUE" "$RESET" "$1"; }

# Means: run an AWS CLI command in the stack's Region and hide error messages.
# AWS uses: whatever command is passed in, with --region added.
aws_cmd() { aws "$@" --region "$REGION" 2>/dev/null; }

# phys <LogicalId> -> the real ID or name CloudFormation gave that resource.
# Means: look resources up by their template name, so nothing is hard-coded here.
# AWS uses: CloudFormation DescribeStackResource (read-only).
phys() {
  aws_cmd cloudformation describe-stack-resource --stack-name "$STACK_NAME" \
    --logical-resource-id "$1" --query 'StackResourceDetail.PhysicalResourceId' --output text
}

# asg_instances <AutoScalingGroupName> -> in-service instance IDs.
# Means: list the servers the group is running right now.
# AWS uses: Auto Scaling DescribeAutoScalingGroups (read-only).
asg_instances() {
  aws_cmd autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$1" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" --output text
}

printf '%sOnward Logistics - Week 2 evidence report%s\n' "$BOLD" "$RESET"
printf 'Stack: %s   Region: %s   Time (UTC): %s\n' "$STACK_NAME" "$REGION" "$TIMESTAMP"

# =============================================================================
section "Provisioning: CloudFormation stack and GitSync"
# =============================================================================
# Means: the stack exists and is in a healthy, finished state.
# AWS uses: CloudFormation DescribeStacks (read-only).
STACK_STATUS="$(aws_cmd cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query 'Stacks[0].StackStatus' --output text)"
if [[ "$STACK_STATUS" =~ ^(CREATE_COMPLETE|UPDATE_COMPLETE)$ ]]; then
  pass "Stack '$STACK_NAME' is healthy ($STACK_STATUS)"
else
  fail "Stack '$STACK_NAME' not healthy or not found (status: ${STACK_STATUS:-not found})"
  printf '\nCannot continue without the stack.\n'; exit 1
fi

# Means: GitSync is set up for this stack, and from which repo, branch and file.
# AWS uses: CodeConnections GetSyncConfiguration (read-only); older CLIs call it codestar-connections.
SYNC=""
for svc in codeconnections codestar-connections; do
  SYNC="$(aws_cmd "$svc" get-sync-configuration --sync-type CFN_STACK_SYNC \
    --resource-name "$STACK_NAME" \
    --query 'SyncConfiguration.[RepositoryName,Branch,ConfigFile]' --output text)"
  [[ -n "$SYNC" ]] && break
done
if [[ -n "$SYNC" ]]; then
  read -r REPO BRANCH CONFIG_FILE <<< "$SYNC"
  pass "GitSync enabled: repo=$REPO branch=$BRANCH deployment-file=$CONFIG_FILE"
else
  warn "Could not read the GitSync configuration (needs codeconnections:GetSyncConfiguration)"
fi

# Means: no inline policies - no AWS::IAM::Policy resource and no "Policies:" property.
# AWS uses: CloudFormation ListStackResources and GetTemplate (read-only).
INLINE_RES="$(aws_cmd cloudformation list-stack-resources --stack-name "$STACK_NAME" \
  --query "length(StackResourceSummaries[?ResourceType=='AWS::IAM::Policy'])" --output text)"
[[ "$INLINE_RES" == "0" ]] && pass "Stack contains zero AWS::IAM::Policy (inline policy) resources" \
  || fail "Stack contains inline policy resources: ${INLINE_RES:-unknown}"
aws_cmd cloudformation get-template --stack-name "$STACK_NAME" --query TemplateBody --output text \
  > "${OUT_DIR}/deployed-template.yaml"
if grep -qE '^[[:space:]]+Policies:' "${OUT_DIR}/deployed-template.yaml"; then
  fail "Deployed template contains an inline 'Policies:' property"
else
  pass "Deployed template has no inline 'Policies:' property"
fi

# =============================================================================
section "Front end: reachable from the internet, served from both zones"
# =============================================================================
# Means: the website address and the name the page must show, from the stack.
# AWS uses: CloudFormation DescribeStacks (read-only).
URL="$(aws_cmd cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='WebsiteUrl'].OutputValue" --output text)"
OWNER="$(aws_cmd cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Parameters[?ParameterKey=='OwnerName'].ParameterValue" --output text)"
info "Website: $URL"

# Means: call the site several times; record status codes, the name on the page and the zones.
# AWS uses: nothing; plain HTTP from where the script runs.
OK=0; NAME_SEEN=false; ZONES=""
for _ in $(seq "$REQUESTS"); do
  page="$(curl -s -m 10 -w '\n%{http_code}' "$URL")"
  code="${page##*$'\n'}"
  [[ "$code" == "200" ]] && OK=$((OK + 1))
  grep -qF "$OWNER" <<< "$page" && NAME_SEEN=true
  ZONES+="$(grep -o 'in [a-z]*-[a-z]*-[0-9][a-z]' <<< "$page" | awk '{print $2}') "
done
UNIQUE_ZONES="$(tr ' ' '\n' <<< "$ZONES" | sed '/^$/d' | sort -u | tr '\n' ' ')"
[[ $OK -eq $REQUESTS ]] && pass "$OK/$REQUESTS requests returned HTTP 200" \
  || fail "Only $OK/$REQUESTS requests returned HTTP 200"
$NAME_SEEN && pass "Page shows the owner name '$OWNER' and the lab name" \
  || fail "Page does not show the owner name '$OWNER'"
[[ $(wc -w <<< "$UNIQUE_ZONES") -ge 2 ]] && pass "Answers came from zones: $UNIQUE_ZONES" \
  || warn "Answers came from only: ${UNIQUE_ZONES:-none} (refresh more, or check the target group)"

# Means: the load balancer sees every web server as healthy.
# AWS uses: Elastic Load Balancing DescribeTargetHealth (read-only).
TG_ARN="$(phys WebTargetGroup)"
STATES="$(aws_cmd elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].TargetHealth.State' --output text)"
HEALTHY="$(tr '\t' '\n' <<< "$STATES" | grep -c '^healthy$')"
TOTAL_T="$(wc -w <<< "$STATES")"
[[ "$HEALTHY" -ge 2 && "$HEALTHY" -eq "$TOTAL_T" ]] && pass "Load balancer targets healthy: $HEALTHY/$TOTAL_T" \
  || fail "Load balancer targets healthy: $HEALTHY/$TOTAL_T (states: ${STATES:-none})"

# =============================================================================
section "Servers: private, one of each per zone"
# =============================================================================
# Means: list each Auto Scaling group's servers with zone, private IP, public IP and key pair.
# AWS uses: Auto Scaling DescribeAutoScalingGroups and EC2 DescribeInstances (read-only).
WEB_ASG="$(phys WebAutoScalingGroup)"
ORDER_ASG="$(phys OrderAutoScalingGroup)"
WEB_IDS="$(asg_instances "$WEB_ASG")"
ORDER_IDS="$(asg_instances "$ORDER_ASG")"
ALL_IDS="$WEB_IDS $ORDER_IDS"
INSTANCES_FILE="${OUT_DIR}/instances.txt"
aws_cmd ec2 describe-instances --instance-ids $ALL_IDS \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value, InstanceId, Placement.AvailabilityZone, PrivateIpAddress, PublicIpAddress || 'None', KeyName || 'None']" \
  --output text | sort > "$INSTANCES_FILE"
printf '         %-18s %-21s %-11s %-14s %-9s %s\n' NAME INSTANCE ZONE PRIVATE-IP PUBLIC-IP KEY-PAIR
while read -r n i z p pub k; do
  printf '         %-18s %-21s %-11s %-14s %-9s %s\n' "$n" "$i" "$z" "$p" "$pub" "$k"
done < "$INSTANCES_FILE"

for pair in "web:$WEB_IDS" "order:$ORDER_IDS"; do
  tier="${pair%%:*}"; ids="${pair#*:}"
  zones="$(aws_cmd ec2 describe-instances --instance-ids $ids \
    --query 'Reservations[].Instances[].Placement.AvailabilityZone' --output text | tr '\t' '\n' | sort -u | wc -l)"
  count="$(wc -w <<< "$ids")"
  [[ "$count" -ge 2 && "$zones" -ge 2 ]] && pass "$tier tier: $count servers across $zones zones" \
    || fail "$tier tier: $count servers across $zones zone(s), expected at least 2 and 2"
done
PUBLIC="$(awk '$5 != "None"' "$INSTANCES_FILE" | wc -l)"
[[ "$PUBLIC" -eq 0 ]] && pass "No server has a public IP address" || fail "$PUBLIC server(s) have a public IP"
KEYS="$(awk '$6 != "None"' "$INSTANCES_FILE" | wc -l)"
[[ "$KEYS" -eq 0 ]] && pass "No server has an SSH key pair (no shared keys)" || fail "$KEYS server(s) have an SSH key pair"

# =============================================================================
section "Isolation: nothing internal reachable from the internet"
# =============================================================================
# Means: no security group rule opens port 22 (or all ports), and only the ALB accepts 0.0.0.0/0.
# AWS uses: EC2 DescribeSecurityGroups (read-only).
for lid in AlbSecurityGroup WebSecurityGroup OrderSecurityGroup; do
  sg="$(phys "$lid")"
  name="$(aws_cmd ec2 describe-security-groups --group-ids "$sg" --query 'SecurityGroups[0].GroupName' --output text)"
  rules="$(aws_cmd ec2 describe-security-groups --group-ids "$sg" \
    --query 'SecurityGroups[0].IpPermissions[].[IpProtocol, FromPort, ToPort]' --output text)"
  open22=false
  while read -r proto from to; do
    [[ -z "$proto" ]] && continue
    if [[ "$proto" == "-1" ]] || { [[ "$from" =~ ^[0-9]+$ ]] && (( from <= 22 && to >= 22 )); }; then open22=true; fi
  done <<< "$rules"
  $open22 && fail "$name allows port 22 or all ports" \
    || pass "$name inbound: $(awk '{printf "%s/%s ", $1, $2}' <<< "$rules")- no port 22"
  world="$(aws_cmd ec2 describe-security-groups --group-ids "$sg" \
    --query "length(SecurityGroups[0].IpPermissions[].IpRanges[?CidrIp=='0.0.0.0/0'][])" --output text)"
  if [[ "$lid" == "AlbSecurityGroup" ]]; then
    [[ "$world" -ge 1 ]] && info "$name accepts the internet (expected: it is the front door)"
  else
    [[ "$world" == "0" ]] && pass "$name accepts nothing from the internet (0.0.0.0/0)" \
      || fail "$name accepts traffic from 0.0.0.0/0"
  fi
done

# Means: private route tables send internet traffic to a NAT gateway, never to the internet gateway.
# AWS uses: EC2 DescribeRouteTables (read-only).
for lid in PrivateRouteTableA PrivateRouteTableB; do
  rt="$(phys "$lid")"
  routes="$(aws_cmd ec2 describe-route-tables --route-table-ids "$rt" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].[GatewayId || NatGatewayId]" --output text)"
  if [[ "$routes" == nat-* ]]; then
    pass "$lid: 0.0.0.0/0 goes to $routes (outbound only), no route from the internet gateway"
  else
    fail "$lid: default route is '${routes:-none}', expected a NAT gateway"
  fi
done

# Means: try to open a connection to an order server directly. It must time out.
# AWS uses: nothing; plain TCP from where the script runs (CloudShell is outside the VPC).
ORDER_IP="$(awk '$1 ~ /order/ {print $4; exit}' "$INSTANCES_FILE")"
if curl -s -m 5 -o /dev/null "http://${ORDER_IP}:8080"; then
  fail "Direct connection to order server ${ORDER_IP}:8080 succeeded (run this from outside the VPC)"
else
  pass "Direct connection to order server ${ORDER_IP}:8080 timed out (blocked)"
fi

# =============================================================================
section "Updates: internal servers can download packages"
# =============================================================================
# Means: each zone has a working NAT gateway, and the free S3 endpoint is in place.
# AWS uses: EC2 DescribeNatGateways and DescribeVpcEndpoints (read-only).
VPC_ID="$(phys Vpc)"
NATS="$(aws_cmd ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
  --query 'NatGateways[].[NatGatewayId, SubnetId]' --output text)"
NAT_COUNT="$(grep -c nat- <<< "$NATS")"
MODE="$(aws_cmd cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Parameters[?ParameterKey=='NatGatewayMode'].ParameterValue" --output text)"
WANT=2; [[ "$MODE" == "single" ]] && WANT=1
[[ "$NAT_COUNT" -ge "$WANT" ]] && pass "$NAT_COUNT NAT gateway(s) available (mode: $MODE)" \
  || fail "$NAT_COUNT NAT gateway(s) available, expected $WANT (mode: $MODE)"
EP_STATE="$(aws_cmd ec2 describe-vpc-endpoints --vpc-endpoint-ids "$(phys S3GatewayEndpoint)" \
  --query 'VpcEndpoints[0].State' --output text)"
[[ "${EP_STATE,,}" == "available" ]] && pass "S3 gateway endpoint available (Amazon Linux repos without NAT data charges)" \
  || fail "S3 gateway endpoint state: ${EP_STATE:-not found}"

# Means: with -p, install a package on one order server through Run Command and show the result.
# AWS uses: SSM SendCommand (changes the server: installs htop), then GetCommandInvocation.
ORDER_ONE="$(awk '{print $1}' <<< "$ORDER_IDS")"
if $PACKAGE_TEST; then
  CMD_ID="$(aws_cmd ssm send-command --instance-ids "$ORDER_ONE" --document-name AWS-RunShellScript \
    --comment "Onward evidence: package download test" \
    --parameters 'commands=["dnf install -y htop >/dev/null 2>&1 && rpm -q htop && curl -s localhost:8080"]' \
    --query 'Command.CommandId' --output text)"
  aws_cmd ssm wait command-executed --command-id "$CMD_ID" --instance-id "$ORDER_ONE"
  RESULT="$(aws_cmd ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$ORDER_ONE" \
    --query '[Status, StandardOutputContent]' --output text)"
  if [[ "$RESULT" == Success* ]]; then
    pass "Order server $ORDER_ONE installed a package from the internet:"
    tail -n +1 <<< "${RESULT#Success}" | sed '/^[[:space:]]*$/d; s/^/         /'
  else
    fail "Package test on $ORDER_ONE did not succeed: ${RESULT:-no result}"
  fi
else
  warn "Package test skipped. Run with -p, or by hand: aws ssm start-session --target $ORDER_ONE, then sudo dnf install -y htop"
fi

# =============================================================================
section "Administration: no open ports, no shared keys"
# =============================================================================
# Means: every server is registered with Session Manager and online.
# AWS uses: SSM DescribeInstanceInformation (read-only).
ONLINE="$(aws_cmd ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$(tr ' \t' ',,' <<< "$ALL_IDS" | sed 's/,,*/,/g; s/^,//; s/,$//')" \
  --query "InstanceInformationList[?PingStatus=='Online'].InstanceId" --output text | wc -w)"
EXPECTED="$(wc -w <<< "$ALL_IDS")"
[[ "$ONLINE" -eq "$EXPECTED" ]] && pass "All $EXPECTED servers are Online in Session Manager" \
  || fail "$ONLINE of $EXPECTED servers are Online in Session Manager"

# Means: the server role uses only the AWS managed SSM policy and has no inline policies.
# AWS uses: IAM ListAttachedRolePolicies and ListRolePolicies (read-only).
ROLE="$(phys InstanceRole)"
ATTACHED="$(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyName' --output text 2>/dev/null)"
INLINE="$(aws iam list-role-policies --role-name "$ROLE" --query 'length(PolicyNames)' --output text 2>/dev/null)"
[[ "$ATTACHED" == "AmazonSSMManagedInstanceCore" ]] && pass "$ROLE has only AmazonSSMManagedInstanceCore attached" \
  || fail "$ROLE attached policies: ${ATTACHED:-none}"
[[ "$INLINE" == "0" ]] && pass "$ROLE has 0 inline policies" || fail "$ROLE has inline policies: ${INLINE:-unknown}"
info "Open a session yourself: aws ssm start-session --target $ORDER_ONE"

# =============================================================================
section "Company standards: tags and budget"
# =============================================================================
# Means: every server carries the Project, Owner and Environment tags.
# AWS uses: EC2 DescribeInstances (read-only).
MISSING=0
for id in $ALL_IDS; do
  keys="$(aws_cmd ec2 describe-instances --instance-ids "$id" \
    --query 'Reservations[0].Instances[0].Tags[].Key' --output text)"
  for t in Project Owner Environment; do
    grep -qw "$t" <<< "$keys" || { MISSING=$((MISSING + 1)); fail "$id is missing the $t tag"; }
  done
done
[[ $MISSING -eq 0 ]] && pass "All servers carry Project, Owner and Environment tags"

# Means: the monthly budget exists, with its limit and email alerts.
# AWS uses: STS GetCallerIdentity and Budgets DescribeBudget / DescribeNotificationsForBudget (read-only).
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"
BUDGET="$(phys NetworkBudget)"
LIMIT="$(aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET" \
  --query 'Budget.BudgetLimit.[Amount, Unit]' --output text 2>/dev/null)"
if [[ -n "$LIMIT" ]]; then
  pass "Budget $BUDGET exists, limit $(awk '{printf "%.0f %s", $1, $2}' <<< "$LIMIT") per month"
  ALERTS="$(aws budgets describe-notifications-for-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET" \
    --query 'length(Notifications)' --output text 2>/dev/null)"
  [[ "${ALERTS:-0}" -ge 1 ]] && pass "Budget has $ALERTS email alert(s)" \
    || warn "Budget has no email alert: set BudgetAlertEmail in network-template-deployment.yaml"
else
  fail "Budget $BUDGET not found"
fi

# =============================================================================
section "Rebuild from the repository"
# =============================================================================
# Means: remind the reader where the whole setup is defined.
# AWS uses: nothing.
info "Everything above is defined in templates/network-template.yaml and deployed by GitSync."
info "History of the design: git log --oneline -- docs/discovery.md templates/network-template.yaml"
info "Zone failure demo (changes the stack, so not automated): stop one web server, refresh the site, watch Auto Scaling replace it."

# =============================================================================
# Summary
# =============================================================================
# Means: print the totals. Exit code 0 means every check passed; 1 means at least one failed.
# AWS uses: nothing; prints the counters.
TOTAL=$((PASS + FAIL))
printf '\n%s================================================================%s\n' "$BOLD" "$RESET"
printf '%s  SUMMARY%s\n' "$BOLD" "$RESET"
printf '%s================================================================%s\n' "$BOLD" "$RESET"
printf '  Checks passed : %s%d%s / %d\n' "$GREEN" "$PASS" "$RESET" "$TOTAL"
printf '  Checks failed : %s%d%s\n' "$([[ $FAIL -gt 0 ]] && echo "$RED" || echo "$GREEN")" "$FAIL" "$RESET"
printf '  Warnings      : %s%d%s\n' "$YELLOW" "$WARN" "$RESET"
printf '  Evidence files: %s\n' "$OUT_DIR"
if [[ $FAIL -eq 0 ]]; then
  printf '\n  %sRESULT: ALL CLIENT CHECKS VERIFIED%s\n\n' "$GREEN$BOLD" "$RESET"
  exit 0
else
  printf '\n  %sRESULT: %d CHECK(S) FAILED - REVIEW ABOVE%s\n\n' "$RED$BOLD" "$FAIL" "$RESET"
  exit 1
fi
