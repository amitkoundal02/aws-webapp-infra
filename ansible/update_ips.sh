#!/bin/bash
set -e

AWS_REGION="ap-south-1"
TAG_KEY="Project"
TAG_VALUE="aws-webapp-infra"

WEB_INSTANCES=$(aws ec2 describe-instances --region "$AWS_REGION" --filters \
  "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
  "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[?contains(Tags[?Key==`Name`].Value | [0], `web`) || contains(Tags[?Key==`Name`].Value | [0], `monitor`) || contains(Tags[?Key==`Name`].Value | [0], `bastion`)].{InstanceId:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress,Tags:Tags}' \
  --output json)

cat > inventory.ini <<'EOF'
[web]
EOF

echo "$WEB_INSTANCES" | jq -r '.[] | select(.Tags | any(.Key=="Name" and (.Value | test("web"; "i")))) | .PublicIpAddress' >> inventory.ini


printf "\n[monitor]\n" >> inventory.ini

echo "$WEB_INSTANCES" | jq -r '.[] | select(.Tags | any(.Key=="Name" and (.Value | test("monitor"; "i")))) | .PublicIpAddress' >> inventory.ini

cat > ~/.ssh/config <<EOF
Host *
  User ec2-user
  IdentityFile ~/.ssh/id_rsa
EOF
