
# ------------------------------------------------------------
# VPC
# ------------------------------------------------------------

resource "aws_vpc" "name" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.owner_id}-vpc"
  }
}

# ------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.name.id
  tags = {
    Name = "${var.owner_id}-igw"
  }
}

resource "aws_route_table" "igw-rt" {
  vpc_id = aws_vpc.name.id

  route {
    cidr_block      = "10.0.2.0/24"
    vpc_endpoint_id = data.aws_vpc_endpoint.endpoint.id
  }

  tags = {
    "Name" = "${var.owner_id}-igw-rt"
  }
}

resource "aws_route_table_association" "igw-rt-assoc" {
  gateway_id     = aws_internet_gateway.igw.id
  route_table_id = aws_route_table.igw-rt.id
}

# ------------------------------------------------------------
# Firewall layer
# ------------------------------------------------------------

resource "aws_subnet" "firewall" {
  vpc_id     = aws_vpc.name.id
  cidr_block = "10.0.4.0/28"
  tags = {
    "Name" = "${var.owner_id}-firewall-subnet"
  }
}
resource "aws_route_table" "firewall-rt" {
  vpc_id = aws_vpc.name.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    "Name" = "${var.owner_id}-firewall-rt"
  }
}

resource "aws_route_table_association" "firewall-rt-assoc" {
  subnet_id      = aws_subnet.firewall.id
  route_table_id = aws_route_table.firewall-rt.id
}

data "aws_vpc_endpoint" "endpoint" {
  vpc_id = aws_vpc.name.id
  state  = "available"

  tags = {
    Firewall                  = aws_networkfirewall_firewall.firewall.arn
    AWSNetworkFirewallManaged = "true"
  }
}

resource "aws_networkfirewall_firewall" "firewall" {
  vpc_id = aws_vpc.name.id
  name   = "${var.owner_id}-firewall"
  subnet_mapping {
    subnet_id = aws_subnet.firewall.id
  }
  firewall_policy_arn = aws_networkfirewall_firewall_policy.example.arn
}

resource "aws_networkfirewall_firewall_policy" "example" {
  name = "example"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.example.arn
    }
  }

  tags = {
    Tag1 = "Value1"
    Tag2 = "Value2"
  }
}

resource "aws_networkfirewall_rule_group" "example" {
  capacity = 100
  name     = "${var.owner_id}-dev-stateful-rule-group"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = ["amazon.it", "www.amazon.com", "amazon.com"]
      }
    }
    stateful_rule_options {
      rule_order = "DEFAULT_ACTION_ORDER"
    }
  }

  tags = {
    Tag1 = "Value1"
    Tag2 = "Value2"
  }
}

# ------------------------------------------------------------
# Workload layer
# ------------------------------------------------------------

resource "aws_subnet" "workload" {
  vpc_id     = aws_vpc.name.id
  cidr_block = "10.0.2.0/24"
  tags = {
    "Name" = "${var.owner_id}-workload-subnet"
  }
}
resource "aws_route_table" "workload-rt" {
  vpc_id = aws_vpc.name.id


  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = data.aws_vpc_endpoint.endpoint.id
  }

  tags = {
    "Name" = "${var.owner_id}-workload-rt"
  }
}

resource "aws_route_table_association" "workload-rt-assoc" {
  subnet_id      = aws_subnet.workload.id
  route_table_id = aws_route_table.workload-rt.id
}
