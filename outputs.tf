output "vpc_id" {
  description = "vpc id"
  value       = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  description = "public subnet id's"
  value       = [aws_subnet.public_subnet.id, aws_subnet.public_subnet2.id]
}

output "private_subnet_ids" {
  description = "private subnet id's"
  value       = [aws_subnet.private_subnet.id, aws_subnet.private_subnet2.id]
}

output "alb_dns_name" {
  description = "alb dns"
  value       = aws_lb.alb.dns_name
}

output "alb_arn" {
  description = "alb arn"
  value       = aws_lb.alb.arn
}

output "web_server_instance_ids" {
  description = "instance id"
  value       = [for instance in aws_instance.web_server : instance.id]
}
