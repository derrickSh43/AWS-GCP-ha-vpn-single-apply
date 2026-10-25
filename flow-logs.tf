resource "aws_default_security_group" "restricted" {
  vpc_id  = aws_vpc.aws_side.id
  ingress = []
  egress  = []
  tags    = { Name = "vpn-unused-default-deny" }
}
resource "aws_cloudwatch_log_group" "flow" {
  #checkov:skip=CKV_AWS_158:Lab flow metadata uses CloudWatch service-side encryption; deploy a customer-managed KMS key for production requirements.
  name_prefix       = "/aws/vpc/aws-gcp-vpn-"
  retention_in_days = 365
}
resource "aws_iam_role" "flow" {
  name_prefix          = "aws-gcp-vpn-flow-"
  permissions_boundary = var.flow_log_permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*" }
      }
    }]
  })
}
data "aws_caller_identity" "current" {}
resource "aws_iam_role_policy" "flow" {
  name = "write-vpc-flow-logs"
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}
resource "aws_flow_log" "workloads" {
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.aws_side.id
  depends_on      = [aws_iam_role_policy.flow]
}
