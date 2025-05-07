output "nlb_dns_name" {
  value = aws_lb.nlb.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.haproxy_asg.name
}
