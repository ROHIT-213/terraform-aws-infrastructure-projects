# Create internet gateway and attach to VPC

resource "aws_internet_gateway" "igw" {                  //connects vpc to internet
  vpc_id = aws_vpc.aws_infra_vpc.id

  tags = {
    Name        = "igw"
    Environment = var.environment
  }
}

# Create public route table with route to IGW

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.aws_infra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"                              //send all internet traffic to igw
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "public-rt"
    Environment = var.environment
  }
}

# Associate public route table with public subnet 1

resource "aws_route_table_association" "pub1_assoc" {      //Attach route table to public subnets
  subnet_id      = aws_subnet.aws_infra_vpc_pub1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate public route table with public subnet 2

resource "aws_route_table_association" "pub2_assoc" {      //Attach route table to public subnets
  subnet_id      = aws_subnet.aws_infra_vpc_pub2.id
  route_table_id = aws_route_table.public_rt.id
}
