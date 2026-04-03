# Allocate Elastic IP for NAT Gateway

resource "aws_eip" "nat_eip" {                               //static public ip required for NAT 
  domain = "vpc"

  tags = {
    Name        = "nat-eip"
    Environment = var.environment
  }
}

# Deploy NAT Gateway in public subnet ap-south-1a

resource "aws_nat_gateway" "nat_gw" {                        //allows private subnet -> internet access but blocks inbound access
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.aws_infra_vpc_pub1.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name        = "nat-gw"
    Environment = var.environment
  }
}

# Private route table routing outbound traffic through NAT Gateway

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.aws_infra_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id               //Route private subnet traffic via NAT
  }

  tags = {
    Name        = "private-rt"
    Environment = var.environment
  }
}

# Associate private route table with private subnet 1 (ap-south-1a)

resource "aws_route_table_association" "private1_assoc" {
  subnet_id      = aws_subnet.aws_infra_vpc_private1.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate private route table with private subnet 2 (ap-south-1b)

resource "aws_route_table_association" "private2_assoc" {
  subnet_id      = aws_subnet.aws_infra_vpc_private2.id
  route_table_id = aws_route_table.private_rt.id
}
