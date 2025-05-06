def lambda_handler(event, context):
    print("Hello from Lambda")
    return {
        'statusCode': 200,
        'body': 'Hello from Lambda!'
    }

    # Any lambda function can be uitilize here 