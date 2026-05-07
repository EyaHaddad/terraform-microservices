# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# Using existing IAM roles from AWS Academy lab
# ECS Task Execution Role - commented out (using existing role)
# resource "aws_iam_role" "ecs_task_execution_role" {...}

# ECS Task Role - commented out (using existing role)
# resource "aws_iam_role" "ecs_task_role" {...}
