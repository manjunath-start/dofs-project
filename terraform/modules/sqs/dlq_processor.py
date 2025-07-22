import json
import boto3
import os
import logging
from datetime import datetime
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Process messages from Dead Letter Queue and save to failed_orders table
    """
    
    try:
        failed_orders_table_name = os.environ.get('FAILED_ORDERS_TABLE_NAME')
        environment = os.environ.get('ENVIRONMENT', 'dev')
        
        if not failed_orders_table_name:
            logger.error("FAILED_ORDERS_TABLE_NAME environment variable not set")
            raise ValueError("FAILED_ORDERS_TABLE_NAME environment variable not set")
        
        failed_orders_table = dynamodb.Table(failed_orders_table_name)
        
        processed_count = 0
        error_count = 0
        
        logger.info(f"Processing {len(event.get('Records', []))} DLQ messages")
        
        for record in event.get('Records', []):
            try:
                # Extract message information
                message_id = record.get('messageId', 'unknown')
                receipt_handle = record.get('receiptHandle', 'unknown')
                
                # Parse the message body
                try:
                    if isinstance(record['body'], str):
                        message_body = json.loads(record['body'])
                    else:
                        message_body = record['body']
                except json.JSONDecodeError:
                    message_body = record['body']
                
                # Extract order data if available
                order_data = None
                order_id = None
                
                if isinstance(message_body, dict):
                    if 'order_id' in message_body:
                        order_data = message_body
                        order_id = message_body['order_id']
                    elif 'order_data' in message_body:
                        order_data = message_body['order_data']
                        order_id = order_data.get('order_id') if order_data else None
                
                if not order_id:
                    order_id = f"dlq-{message_id}-{int(datetime.utcnow().timestamp())}"
                
                # Create failed order record
                failed_order = {
                    'order_id': order_id,
                    'failed_at': datetime.utcnow().isoformat(),
                    'failure_source': 'DLQ',
                    'status': 'DLQ_PROCESSING_FAILED',
                    'message_id': message_id,
                    'receipt_handle': receipt_handle,
                    'environment': environment,
                    'original_message': convert_floats_to_decimal(message_body),
                    'dlq_metadata': {
                        'processed_at': datetime.utcnow().isoformat(),
                        'processor_version': '1.0',
                        'message_attributes': record.get('messageAttributes', {}),
                        'approximate_receive_count': record.get('attributes', {}).get('ApproximateReceiveCount', 'unknown')
                    }
                }
                
                # Add order data if available
                if order_data:
                    failed_order['original_order_data'] = convert_floats_to_decimal(order_data)
                    failed_order['customer_name'] = order_data.get('customer_name', 'unknown')
                    failed_order['customer_email'] = order_data.get('customer_email', 'unknown')
                    
                    # Calculate order value if items exist
                    if 'items' in order_data and isinstance(order_data['items'], list):
                        total_value = 0
                        for item in order_data['items']:
                            quantity = item.get('quantity', 0)
                            price = item.get('unit_price') or item.get('price', 0)
                            total_value += quantity * price
                        failed_order['order_value'] = Decimal(str(total_value))
                        failed_order['item_count'] = len(order_data['items'])
                
                # Store in failed orders table
                failed_orders_table.put_item(Item=failed_order)
                
                logger.info(f"DLQ message processed successfully", extra={
                    'order_id': order_id,
                    'message_id': message_id,
                    'failure_source': 'DLQ',
                    'processed_at': datetime.utcnow().isoformat()
                })
                
                processed_count += 1
                
            except Exception as e:
                logger.error(f"Error processing DLQ record {record.get('messageId', 'unknown')}: {str(e)}")
                error_count += 1
                
                # Try to save the problematic record anyway
                try:
                    error_record = {
                        'order_id': f"error-{record.get('messageId', 'unknown')}-{int(datetime.utcnow().timestamp())}",
                        'failed_at': datetime.utcnow().isoformat(),
                        'failure_source': 'DLQ_PROCESSOR_ERROR',
                        'status': 'DLQ_PROCESSOR_FAILED',
                        'error_message': str(e),
                        'environment': environment,
                        'original_record': record,
                        'dlq_metadata': {
                            'processed_at': datetime.utcnow().isoformat(),
                            'processor_version': '1.0',
                            'processing_error': True
                        }
                    }
                    failed_orders_table.put_item(Item=error_record)
                except:
                    logger.error("Failed to save error record for DLQ message processing failure")
        
        logger.info(f"DLQ processing complete", extra={
            'processed_count': processed_count,
            'error_count': error_count,
            'total_records': len(event.get('Records', [])),
            'environment': environment
        })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'DLQ processing completed',
                'processed_count': processed_count,
                'error_count': error_count,
                'total_records': len(event.get('Records', []))
            })
        }
        
    except Exception as e:
        logger.error(f"Critical error in DLQ processor: {str(e)}")
        raise

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