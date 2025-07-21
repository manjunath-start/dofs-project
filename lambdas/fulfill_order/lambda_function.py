import json
import boto3
import os
import logging
import random
from datetime import datetime
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    Process orders from SQS queue and fulfill them
    """
    
    orders_table_name = os.environ.get('ORDERS_TABLE_NAME')
    failed_orders_table_name = os.environ.get('FAILED_ORDERS_TABLE_NAME')
    
    orders_table = dynamodb.Table(orders_table_name)
    failed_orders_table = dynamodb.Table(failed_orders_table_name)
    
    processed_count = 0
    failed_count = 0
    
    for record in event['Records']:
        try:
            # Parse SQS message
            message_body = json.loads(record['body'])
            order_data = message_body if 'order_id' in message_body else json.loads(message_body)
            
            order_id = order_data['order_id']
            logger.info(f"Processing order fulfillment for order_id: {order_id}")
            
            # Simulate fulfillment process
            fulfillment_result = simulate_fulfillment(order_data)
            
            if fulfillment_result['success']:
                # Update order status to FULFILLED
                order_data.update({
                    'status': 'FULFILLED',
                    'fulfillment_timestamp': datetime.utcnow().isoformat(),
                    'fulfillment_details': fulfillment_result['details'],
                    'tracking_number': fulfillment_result.get('tracking_number'),
                    'updated_at': datetime.utcnow().isoformat()
                })
                
                # Convert floats to Decimal for DynamoDB
                order_data = convert_floats_to_decimal(order_data)
                
                # Save fulfilled order
                orders_table.put_item(Item=order_data)
                
                logger.info(f"Order {order_id} fulfilled successfully")
                processed_count += 1
                
            else:
                # Handle fulfillment failure
                logger.error(f"Fulfillment failed for order {order_id}: {fulfillment_result['error']}")
                
                # Update order status to FULFILLMENT_FAILED
                order_data.update({
                    'status': 'FULFILLMENT_FAILED',
                    'fulfillment_timestamp': datetime.utcnow().isoformat(),
                    'error_message': fulfillment_result['error'],
                    'retry_count': order_data.get('retry_count', 0) + 1,
                    'updated_at': datetime.utcnow().isoformat()
                })
                
                # Convert floats to Decimal for DynamoDB
                order_data = convert_floats_to_decimal(order_data)
                
                # Move to failed orders table if max retries exceeded
                if order_data['retry_count'] >= 3:
                    failed_orders_table.put_item(Item=order_data)
                    logger.info(f"Order {order_id} moved to failed orders table after {order_data['retry_count']} retries")
                else:
                    # Save back to orders table for potential retry
                    orders_table.put_item(Item=order_data)
                    logger.info(f"Order {order_id} marked as fulfillment failed, retry count: {order_data['retry_count']}")
                
                failed_count += 1
                
        except Exception as e:
            logger.error(f"Error processing record {record.get('messageId', 'unknown')}: {str(e)}")
            failed_count += 1
            
            # Optionally save the problematic order to failed orders table
            try:
                failed_order = {
                    'order_id': f"error-{record.get('messageId', 'unknown')}-{int(datetime.utcnow().timestamp())}",
                    'original_record': record,
                    'error_message': str(e),
                    'failed_at': datetime.utcnow().isoformat(),
                    'status': 'PROCESSING_ERROR'
                }
                failed_orders_table.put_item(Item=failed_order)
            except:
                logger.error("Failed to save error record to failed orders table")
    
    logger.info(f"Fulfillment processing complete. Processed: {processed_count}, Failed: {failed_count}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed_orders': processed_count,
            'failed_orders': failed_count,
            'total_records': len(event['Records'])
        })
    }

def simulate_fulfillment(order_data):
    """
    Simulate order fulfillment process
    Returns success/failure with details
    """
    
    # Simulate random fulfillment success/failure (90% success rate)
    success_rate = 0.9
    is_successful = random.random() < success_rate
    
    if is_successful:
        # Generate tracking number
        tracking_number = f"TRACK{random.randint(100000, 999999)}"
        
        return {
            'success': True,
            'tracking_number': tracking_number,
            'details': {
                'fulfillment_center': 'FC-01',
                'estimated_delivery': get_estimated_delivery(),
                'shipping_method': 'STANDARD',
                'items_fulfilled': len(order_data.get('items', []))
            }
        }
    else:
        # Simulate different failure reasons
        failure_reasons = [
            'Insufficient inventory',
            'Payment authorization failed',
            'Invalid shipping address',
            'Product discontinued',
            'Fulfillment center unavailable'
        ]
        
        return {
            'success': False,
            'error': random.choice(failure_reasons)
        }

def get_estimated_delivery():
    """
    Calculate estimated delivery date (3-7 business days)
    """
    from datetime import timedelta
    
    delivery_days = random.randint(3, 7)
    estimated_date = datetime.utcnow() + timedelta(days=delivery_days)
    return estimated_date.isoformat()

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
