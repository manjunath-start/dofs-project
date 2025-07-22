import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Validate order data from Step Functions
    """
    
    try:
        logger.info(f"Validating order: {json.dumps(event)}")
        
        # Required fields for an order
        required_fields = ['order_id', 'customer_name', 'customer_email', 'items']
        
        # Check for required fields
        for field in required_fields:
            if field not in event or not event[field]:
                error_msg = f"Missing or empty required field: {field}"
                logger.error(error_msg)
                raise ValueError(error_msg)
        
        # Validate email format (basic validation)
        email = event['customer_email']
        if '@' not in email or '.' not in email:
            error_msg = "Invalid email format"
            logger.error(error_msg)
            raise ValueError(error_msg)
        
        # Validate items
        items = event['items']
        if not isinstance(items, list) or len(items) == 0:
            error_msg = "Items must be a non-empty list"
            logger.error(error_msg)
            raise ValueError(error_msg)
        
        # Validate each item
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                error_msg = f"Item {i} must be an object"
                logger.error(error_msg)
                raise ValueError(error_msg)
            
            item_required_fields = ['product_id', 'quantity']
            for field in item_required_fields:
                if field not in item:
                    error_msg = f"Item {i} missing required field: {field}"
                    logger.error(error_msg)
                    raise ValueError(error_msg)
            
            # Check for price field (accept either 'price' or 'unit_price')
            price_value = None
            if 'price' in item:
                price_value = item['price']
            elif 'unit_price' in item:
                price_value = item['unit_price']
            else:
                error_msg = f"Item {i} missing price field (must have 'price' or 'unit_price')"
                logger.error(error_msg)
                raise ValueError(error_msg)
            
            # Validate quantity and price are positive numbers
            if not isinstance(item['quantity'], (int, float)) or item['quantity'] <= 0:
                error_msg = f"Item {i} quantity must be a positive number"
                logger.error(error_msg)
                raise ValueError(error_msg)
            
            if not isinstance(price_value, (int, float)) or price_value <= 0:
                error_msg = f"Item {i} price must be a positive number"
                logger.error(error_msg)
                raise ValueError(error_msg)
        
        # Validate total_amount if provided
        if 'total_amount' in event:
            provided_total = event['total_amount']
            if not isinstance(provided_total, (int, float)) or provided_total <= 0:
                error_msg = "Total amount must be a positive number"
                logger.error(error_msg)
                raise ValueError(error_msg)
        
        # Calculate total amount from items
        calculated_total = sum(item['quantity'] * (item.get('price') or item.get('unit_price')) for item in items)
        
        # Add validation metadata
        validated_order = {
            **event,
            'validation_timestamp': datetime.utcnow().isoformat(),
            'calculated_total_amount': round(calculated_total, 2),
            'status': 'VALIDATED'
        }
        
        logger.info(f"Order validation successful for order {event['order_id']}")
        
        return validated_order
        
    except Exception as e:
        logger.error(f"Order validation failed: {str(e)}")
        raise