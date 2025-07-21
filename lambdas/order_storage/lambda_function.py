import json
import boto3
import os
import logging
from datetime import datetime
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    Store validated order in DynamoDB and send to SQS for fulfillment
    """
    
    try:
        logger.info(f"Processing order storage: {json.dumps(event, default=str)}")
        
        # Get environment variables
        orders_table_name = os.environ.get('ORDERS_TABLE_NAME')
        order_queue_url = os.environ.get('ORDER_QUEUE_URL')
        
        if not orders_table_name:
            raise ValueError("ORDERS_TABLE_NAME environment variable not set")
        if not order_queue_url:
            raise ValueError("ORDER_QUEUE_URL environment variable not set")
        
        # Get DynamoDB table
        orders_table = dynamodb.Table(orders_table_name)
        
        # Prepare order data for storage
        order_data = prepare_order_for_storage(event)
        
        # Convert floats to Decimal for DynamoDB compatibility
        order_data = convert_floats_to_decimal(order_data)
        
        # Store order in DynamoDB
        logger.info(f"Storing order {order_data['order_id']} in DynamoDB table {orders_table_name}")
        
        response = orders_table.put_item(
            Item=order_data,
            ConditionExpression='attribute_not_exists(order_id)'
        )
        
        logger.info(f"Order {order_data['order_id']} stored successfully in DynamoDB")
        
        # Send order to SQS queue for fulfillment
        logger.info(f"Sending order {order_data['order_id']} to SQS queue for fulfillment")
        
        # Convert Decimal back to float for SQS message
        sqs_message = convert_decimal_to_float(order_data)
        
        sqs_response = sqs.send_message(
            QueueUrl=order_queue_url,
            MessageBody=json.dumps(sqs_message),
            MessageAttributes={
                'order_id': {
                    'StringValue': order_data['order_id'],
                    'DataType': 'String'
                },
                'order_status': {
                    'StringValue': order_data['status'],
                    'DataType': 'String'
                }
            }
        )
        
        logger.info(f"Order {order_data['order_id']} sent to SQS queue. MessageId: {sqs_response['MessageId']}")
        
        # Return the stored order data for Step Functions
        return {
            **order_data,
            'storage_timestamp': order_data['storage_timestamp'],
            'sqs_message_id': sqs_response['MessageId']
        }
        
    except Exception as e:
        logger.error(f"Error storing order: {str(e)}")
        
        # Update order status to indicate storage failure
        error_order = {
            **event,
            'status': 'STORAGE_FAILED',
            'error_message': str(e),
            'storage_timestamp': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        # Still try to store the failed order for debugging
        try:
            if orders_table_name:
                failed_orders_table = dynamodb.Table(orders_table_name)
                failed_orders_table.put_item(Item=convert_floats_to_decimal(error_order))
        except:
            logger.error("Failed to store error order in DynamoDB")
        
        raise

def prepare_order_for_storage(order_data):
    """
    Prepare order data with storage metadata
    """
    
    current_time = datetime.utcnow().isoformat()
    
    # Base order data
    storage_order = {
        **order_data,
        'status': 'STORED',
        'storage_timestamp': current_time,
        'updated_at': current_time
    }
    
    # Ensure required fields exist
    if 'created_at' not in storage_order:
        storage_order['created_at'] = current_time
    
    # Add order metadata if not present
    if 'order_metadata' not in storage_order:
        storage_order['order_metadata'] = {
            'source': 'api',
            'version': '1.0'
        }
    
    # Calculate order summary
    if 'items' in storage_order:
        total_items = len(storage_order['items'])
        total_quantity = sum(item.get('quantity', 0) for item in storage_order['items'])
        
        storage_order['order_summary'] = {
            'total_items': total_items,
            'total_quantity': total_quantity,
            'currency': 'USD'
        }
    
    return storage_order

def convert_floats_to_decimal(obj):
    """
    Convert float values to Decimal for DynamoDB compatibility
    """
    if isinstance(obj, list):
        return [convert_floats_to_decimal(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_floats_to_decimal(value) for key, value in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    else:
        return obj

def convert_decimal_to_float(obj):
    """
    Convert Decimal values back to float for JSON serialization
    """
    if isinstance(obj, list):
        return [convert_decimal_to_float(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_decimal_to_float(value) for key, value in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj
