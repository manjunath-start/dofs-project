import json
import boto3
import os
import logging
import uuid
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

stepfunctions = boto3.client('stepfunctions')

def lambda_handler(event, context):
    """
    API Gateway handler that receives order requests and triggers Step Functions
    """
    
    try:
        # Parse the request
        if 'body' not in event:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing request body'
                })
            }
        
        # Parse JSON body
        try:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        except json.JSONDecodeError:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Invalid JSON in request body'
                })
            }
        
        # Generate order ID and add metadata
        order_id = str(uuid.uuid4())
        order_data = {
            'order_id': order_id,
            'created_at': datetime.utcnow().isoformat(),
            'status': 'RECEIVED',
            **body
        }
        
        # Get Step Function ARN from environment or construct it
        project_name = os.environ.get('PROJECT_NAME', 'dofs')
        environment = os.environ.get('ENVIRONMENT', 'dev')
        region = os.environ.get('AWS_DEFAULT_REGION', context.invoked_function_arn.split(':')[3])
        account_id = context.invoked_function_arn.split(':')[4]
        
        state_machine_arn = f"arn:aws:states:{region}:{account_id}:stateMachine:{project_name}-order-processor-{environment}"
        
        # Start Step Function execution
        response = stepfunctions.start_execution(
            stateMachineArn=state_machine_arn,
            name=f"order-{order_id}-{int(datetime.utcnow().timestamp())}",
            input=json.dumps(order_data)
        )
        
        logger.info(f"Started Step Function execution for order {order_id}: {response['executionArn']}")
        
        return {
            'statusCode': 202,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Order received and processing started',
                'order_id': order_id,
                'execution_arn': response['executionArn']
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing order: {str(e)}")
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }