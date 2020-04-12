# Example Lambda function template

The Example.template file shows a sample template for each of your lambda.

The template includes:

   * The Lambda definition
   * The IAM Role and Policy
   * The CloudWatch log collection configuration
   * The CloudWatch log filter and alarm

## Adapt the example for your Lambda

Rename everything in there to match your Lambda name.

Edit the `LambdaExecutionRolePolicy` to give proper access to the AWS resources you need.

Edit the AlarmActions to point to the correct SNS Notification ARN if you want.

