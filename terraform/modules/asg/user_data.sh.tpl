#!/bin/bash

dnf update -y
dnf install -y httpd
systemctl enable httpd
systemctl start httpd

cat > /var/www/html/index.html <<'EOF'
${index_content}
EOF

cat > /var/www/html/health <<'EOF'
${health_content}
EOF

chmod 644 /var/www/html/index.html /var/www/html/health

# CloudWatch agent can be installed here if needed
