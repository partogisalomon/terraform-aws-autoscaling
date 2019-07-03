module "launch_template_name" {
  source = "github.com/traveloka/terraform-aws-resource-naming.git?ref=v0.16.1"

  name_prefix   = "${var.service_name}-${var.cluster_role}"
  resource_type = "launch_configuration"
}

module "asg_name" {
  source = "github.com/traveloka/terraform-aws-resource-naming.git?ref=v0.16.1"

  name_prefix   = "${var.service_name}-${var.cluster_role}"
  resource_type = "autoscaling_group"

  keepers = {
    image_id                  = "${data.aws_ami.latest_service_image.id}"
    instance_profile          = "${var.instance_profile}"
    key_name                  = "${var.key_name}"
    security_groups           = "${join(",", sort(var.security_groups))}"
    user_data                 = "${var.user_data}"
    monitoring                = "${var.monitoring}"
    ebs_optimized             = "${var.ebs_optimized}"
    ebs_volume_size           = "${var.volume_size}"
    ebs_volume_type           = "${var.volume_type}"
    ebs_delete_on_termination = "${var.delete_on_termination}"
  }
}

resource "aws_launch_configuration" "main" {
  name = "${module.launch_template_name.name}"

  image_id = "${data.aws_ami.latest_service_image.id}"

  iam_instance_profile   = "${var.instance_profile}"
  instance_type          = "${var.instance_type}"

  key_name               = "${var.key_name}"
  security_groups        = ["${var.security_groups}"]
  user_data              = "${var.user_data}"

  enable_monitoring      = "${var.monitoring}"
  ebs_optimized          = "${var.ebs_optimized}"

  root_block_device =
  {
    volume_size           = "10"
    volume_type           = "${var.volume_type}"
    delete_on_termination = "${var.delete_on_termination}"
  }

  ebs_block_device = [
  {
    device_name           = "/dev/xvdb"
    volume_size           = "500"
    volume_type           = "gp2"
    delete_on_termination = "true"
  }]

}

resource "aws_autoscaling_group" "main" {
  name                      = "${module.asg_name.name}"
  max_size                  = "${var.asg_max_capacity}"
  min_size                  = "${var.asg_min_capacity}"
  default_cooldown          = "${var.asg_default_cooldown}"
  health_check_grace_period = "${var.asg_health_check_grace_period}"
  health_check_type         = "${var.asg_health_check_type}"
  vpc_zone_identifier       = ["${var.asg_vpc_zone_identifier}"]
  target_group_arns         = ["${var.asg_lb_target_group_arns}"]
  load_balancers            = ["${var.asg_clb_names}"]
  termination_policies      = ["${var.asg_termination_policies}"]
  launch_configuration      = "${aws_launch_configuration.main.name}"

  tags = [
    {
      key                 = "Name"
      value               = "${module.asg_name.name}"
      propagate_at_launch = true
    },
    {
      key                 = "Service"
      value               = "${var.service_name}"
      propagate_at_launch = true
    },
    {
      key                 = "ProductDomain"
      value               = "${var.product_domain}"
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = ${var.service_name}-${var.cluster_role}"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "${var.environment}"
      propagate_at_launch = true
    },
    {
      key                 = "Description"
      value               = "ASG of the ${var.service_name}-${var.cluster_role} cluster"
      propagate_at_launch = true
    },
    {
      key                 = "ManagedBy"
      value               = "terraform"
      propagate_at_launch = true
    },
    {
      key                 = "keep_alive"
      value               = "true"
      propagate_at_launch = true
    },
    "${var.asg_tags}",
  ]

  placement_group           = "${var.asg_placement_group}"
  metrics_granularity       = "${var.asg_metrics_granularity}"
  enabled_metrics           = "${var.asg_enabled_metrics}"
  wait_for_capacity_timeout = "${var.asg_wait_for_capacity_timeout}"
  wait_for_elb_capacity     = "${local.asg_wait_for_elb_capacity}"
  service_linked_role_arn   = "${var.asg_service_linked_role_arn}"

  lifecycle {
    create_before_destroy = true
  }
}
