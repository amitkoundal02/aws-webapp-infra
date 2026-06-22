#!/bin/bash
set -e

AWS_REGION="ap-south-1"
TAG_KEY="Project"
TAG_VALUE="aws-webapp-infra"

echo "Fetching running instances tagged ${TAG_KEY}=${TAG_VALUE}..."

WEB_INSTANCES=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
    "Name=instance-state-name,Values=running" \
  --output json)

WEB_IPS=$(echo "$WEB_INSTANCES" | jq -r '
  .Reservations[].Instances[] |
  select(
    .Tags != null and
    (.Tags[] | select(.Key == "Name") | .Value | ascii_downcase |
     ((contains("web") or contains("asg")) and (contains("monitor") | not)))
  ) |
  .PublicIpAddress // empty
')

MONITOR_IPS=$(echo "$WEB_INSTANCES" | jq -r '
  .Reservations[].Instances[] |
  select(
    .Tags != null and
    (.Tags[] | select(.Key == "Name") | .Value | ascii_downcase | contains("monitor"))
  ) |
  .PublicIpAddress // empty
')

echo "Web IPs found:     ${WEB_IPS:-NONE}"
echo "Monitor IPs found: ${MONITOR_IPS:-NONE}"

cat > inventory.ini << INVENTORY
[web]
${WEB_IPS}

[monitor]
${MONITOR_IPS}
INVENTORY

echo ""
echo "=== inventory.ini ==="
cat inventory.ini

cat > ~/.ssh/config << SSHCONFIG
Host *
  User ec2-user
  IdentityFile ~/.ssh/instance_key.pem
  StrictHostKeyChecking no
  ServerAliveInterval 60
SSHCONFIG

chmod 600 ~/.ssh/config
echo ""
echo "SSH config updated — using instance_key.pem"
echo "Done."
