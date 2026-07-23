# vpc.tf
# The network foundation. Every AWS compute resource lives inside a VPC (Virtual
# Private Cloud) — your own isolated private network in AWS. Below we build:
#   VPC -> Subnets -> Internet Gateway -> Route Table -> Associations
# so our EC2 instance can reach (and be reached from) the internet.

# The VPC itself: a private IP range (10.0.0.0/16 = 65,536 addresses).
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # let instances resolve DNS names
  enable_dns_hostnames = true # give instances DNS hostnames

  tags = { Name = "${local.name_prefix}-vpc" }
}

# Public subnets: smaller slices of the VPC placed in different AZs. "Public"
# means they have a route to the internet (added via the route table below).
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # instances here get a public IP automatically

  tags = { Name = "${local.name_prefix}-public-${count.index}" }
}

# Internet Gateway: the door between the VPC and the public internet. Without it,
# nothing in the VPC can talk to the outside world.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# Route table: rules for where network traffic goes. This one sends all traffic
# destined for outside the VPC (0.0.0.0/0 = "anywhere") to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

# Associate the route table with each public subnet so the rules apply to them.
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
