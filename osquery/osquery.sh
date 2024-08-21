#!/bin/sh

# Install osquery
curl -L https://pkg.osquery.io/rpm/GPG | sudo tee /etc/pki/rpm-gpg/RPM-GPG-KEY-osquery
sudo yum-config-manager --add-repo https://pkg.osquery.io/rpm/osquery-s3-rpm.repo
sudo yum-config-manager --enable osquery-s3-rpm-repo
sudo yum install osquery -y

# Move osquery configuration files from SSM parameter store
aws ssm get-parameter --name=osquery_configuration_file | jq -r '.[] | .Value' > /etc/osquery/osquery.conf
aws ssm get-parameter --name=osquery_flag_file | jq -r '.[] | .Value' > /etc/osquery/osquery.flags

# Start osquery
sudo systemctl start osqueryd
