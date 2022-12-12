"""
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

Blog Post Project.....: IoT Analytical System

Code Purpose: 

This code will be used by a Lambda Function.
It will read the output of an Athena query - which is 
written to a S3 bucket as a CSV file, with summarized 
IoT electricity metering data - and will write 
each line of this file as an item into a DynamoDB table,
called "ElectricityMeteredByPeriod".
The Lambda function will be triggered when a new
CSV file, containing Athena query results, is uploaded 
to the S3 bucket which holds the Athena outputs, into 
prefix "electricity_by_period/"
"""
import os
import tempfile
import csv
import json
import urllib.parse
import boto3
from decimal import Decimal

s3 = boto3.client('s3')
ddb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    # Get the object metadata from S3 "All object create events"
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    
    # Setting variables to capture metadata and validate this invocation
    key_prefix = key[0:(key.find("/"))]
    
    try:
        if key_prefix == "electricity_by_period":
            tmpdir = tempfile.mkdtemp()
            saved_umask = os.umask(0o77)
            download_path = os.path.join(tmpdir, "electricity_by_period.csv")
        else:
            assert (True), "Not a valid Key prefix! Current value = " + key_prefix
    except AssertionError as e:
        print(e)
        raise e
    
    # Setting common variables
    ddb_table_name = "ElectricityMeteredByPeriod"
    ddb_table_hash = "CustomerID"
    ddb_table_range = "SensorID-Period"
    ddb_table_attribute = "kWh-Amount"
    csv_header_hash = "customerid"
    
    # Instantiate the table to be written
    ddb_table = ddb.Table(ddb_table_name)
    
    print("Writing Athena query output into DynamoDB table " + ddb_table_name + "\n")
    
    # Downloading the CSV file to /tmp directory
    try:
        s3.download_file(bucket, key, download_path)
    except Exception as e:
        print(e)
        print("Error downloading S3 object %s from bucket %d." % (key, bucket))
        raise e
    
    # Iterate with each line from CSV file, generating an Items list, in JSON format.
    try:
        # Initialize the Items list variable
        items = []
        
        # Iterate over CSV file and generates Items list
        with open(download_path, 'r') as csv_file:
            csv_obj = csv.reader(csv_file)
            for row in csv_obj:
                if row[0] != csv_header_hash:
                    json_item = '{"' + ddb_table_hash + '": ' + row[0] + ', "' + ddb_table_range + '": "' + row[1] + '", "' + ddb_table_attribute + '": ' + row[2] + '}'
                    items.append(json.loads(json_item, parse_float=Decimal))
    except Exception as e:
        print(e)
        print("Error working in file:", download_path)
        raise e
    else:
        os.remove(download_path)
    finally:
        os.umask(saved_umask)
        os.rmdir(tmpdir)
    
    # Write each member from Items list as an item into DynamDB table defined in variable "ddb_table_name"
    # Using batch_writer() action to automatically handle buffering and send items in batches.
    with ddb_table.batch_writer() as batch:
        for item in items:
            try:
                batch.put_item(Item=item)
                print('Writing metering data for item:')
                print(item)
            except Exception as e:
                print(e)
                print('Error writing metering data for item:')
                print(item)
                raise e
