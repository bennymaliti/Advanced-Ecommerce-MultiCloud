# This module creates CloudWatch dashboards and SNS topics for monitoring

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  display_name      = "${var.project_name} Infrastructure Alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alerts"
    }
  )
}

# SNS Topic Subscription for email
resource "aws_sns_topic_subscription" "alerts_email" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average", label = "Avg Response Time" }],
            [".", "RequestCount", { stat = "Sum", label = "Request Count" }],
            [".", "HTTPCode_Target_2XX_Count", { stat = "Sum", label = "2XX Responses" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum", label = "4XX Errors" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", label = "5XX Errors" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Application Load Balancer Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "Avg CPU" }],
            [".", ".", { stat = "Maximum", label = "Max CPU" }],
            [".", "NetworkIn", { stat = "Sum", label = "Network In" }],
            [".", "NetworkOut", { stat = "Sum", label = "Network Out" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 Instance Metrics"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }],
            [".", "DatabaseConnections", { stat = "Average", label = "DB Connections" }],
            [".", "FreeableMemory", { stat = "Average", label = "Freeable Memory" }],
            [".", "ReadLatency", { stat = "Average", label = "Read Latency" }],
            [".", "WriteLatency", { stat = "Average", label = "Write Latency" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Database Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", { stat = "Average", label = "CPU Utilization" }],
            [".", "DatabaseMemoryUsagePercentage", { stat = "Average", label = "Memory Usage %" }],
            [".", "CacheHits", { stat = "Sum", label = "Cache Hits" }],
            [".", "CacheMisses", { stat = "Sum", label = "Cache Misses" }],
            [".", "Evictions", { stat = "Sum", label = "Evictions" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ElastiCache Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", { stat = "Sum", label = "Total Requests" }],
            [".", "BytesDownloaded", { stat = "Sum", label = "Bytes Downloaded" }],
            [".", "BytesUploaded", { stat = "Sum", label = "Bytes Uploaded" }],
            [".", "4xxErrorRate", { stat = "Average", label = "4xx Error Rate" }],
            [".", "5xxErrorRate", { stat = "Average", label = "5xx Error Rate" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront Distribution Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 24
        height = 6
        x      = 0
        y      = 12
      }
    ]
  })
}

# CloudWatch Log Metric Filter for Application Errors
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.project_name}-app-errors"
  log_group_name = "/aws/ec2/${var.project_name}"
  pattern        = "[ERROR]"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "${var.project_name}/Application"
    value     = "1"
  }
}

# CloudWatch Alarm for Application Errors
resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${var.project_name}-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApplicationErrors"
  namespace           = "${var.project_name}/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors application errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.common_tags
}

# Create CloudWatch Composite Alarm for critical failures
resource "aws_cloudwatch_composite_alarm" "critical_failure" {
  alarm_name          = "${var.project_name}-critical-failure"
  alarm_description   = "Composite alarm for critical infrastructure failures"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  alarm_rule = join(" OR ", [
    "ALARM(${var.alb_unhealthy_alarm_name})",
    "ALARM(${var.rds_cpu_alarm_name})",
    "ALARM(${var.cache_cpu_alarm_name})"
  ])

  tags = var.common_tags
}

# CloudWatch Log Insights Query for common issues
resource "aws_cloudwatch_query_definition" "common_errors" {
  name = "${var.project_name}-common-errors"

  log_group_names = [
    "/aws/ec2/${var.project_name}",
    "/aws/rds/${var.project_name}",
    "/aws/elasticache/${var.project_name}"
  ]

  query_string = <<-QUERY
    fields @timestamp, @message
    | filter @message like /ERROR/
    | stats count() by bin(5m)
  QUERY
}

# EventBridge Rule for Auto Scaling Events
resource "aws_cloudwatch_event_rule" "autoscaling_events" {
  name        = "${var.project_name}-autoscaling-events"
  description = "Capture Auto Scaling events"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = [
      "EC2 Instance Launch Successful",
      "EC2 Instance Launch Unsuccessful",
      "EC2 Instance Terminate Successful",
      "EC2 Instance Terminate Unsuccessful"
    ]
  })

  tags = var.common_tags
}

# EventBridge Target for Auto Scaling Events
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.autoscaling_events.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}

# SNS Topic Policy for EventBridge
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}