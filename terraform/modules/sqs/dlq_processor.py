def lambda_handler(event, context):
    print("Received event:", event)
    # Add your DLQ processing logic here
    return {"statusCode": 200, "body": "Processed"} 