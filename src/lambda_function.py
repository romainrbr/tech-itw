#!/usr/bin/env python3

import requests
import json
import boto3
import time
import os

# Error codes
# Success : 0
# HTTP error : 10
# Connection error : 11
# Other HTTP issue : 19
# Json invalid : 20

# Takes an URL as parameter, and returns the content if it serves valid json.
def ingestUrl(url):
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
    except requests.exceptions.HTTPError:
        raise SystemExit(10)
    except requests.exceptions.ConnectionError:
        raise SystemExit(11)
    except requests.exceptions.RequestException:
        raise SystemExit(19)
    try:
        json.loads(r.text)
    except Exception:
        raise SystemExit(20)
    return json.dumps(r.json())

# Upload a string to an S3 bucket, using the current timestamp as filename, and storing it in a specific path.
def uploadToS3(bucketName, endpointName, timestamp, content):
    string = content
    encoded_string = string.encode("utf-8")
    fileName = f"{timestamp}.json"
    s3_path = f"{endpointName}/{fileName}"
    s3 = boto3.resource("s3")
    s3.Bucket(bucketName).put_object(Key=s3_path, Body=encoded_string)

# Lambda function that runs both ingestUrl, and uploadToS3.
# Returns 200 if both function worked.
def lambda_handler(event, context):
    timestamp = round(time.time())
    endpointUrl = os.environ['endpointUrl']
    endpointName = os.environ['endpointName']
    bucketName = os.environ['bucketName']

    content = ingestUrl(endpointUrl)
    uploadToS3(bucketName, endpointName, timestamp, content)

    return {
        'statusCode': 200,
        'body': "ok"
    }
