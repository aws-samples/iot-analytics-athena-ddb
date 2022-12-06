"""
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

Blog Post Project.....: IoT Analytical System

Code Purpose: 

This code will be used by a Lambda Function.
It will run an Athena queries to summarize electricity 
metering data uploaded to a S3 bucket, as CSV files, 
by hour, day and month.
The Lambda function will be triggered daily, at 00h30 
in Brasilia time zone (UTC-03:00), based in a scheduled event.
"""
import os
import boto3
from datetime import datetime
from datetime import timedelta
import calendar

print("Running Athena queries daily, after CSV uploaded to S3" + "\n")

athena = boto3.client('athena')
athena_output_location = os.environ.get('ev_athena_output_location')

print("Output Location for Athena results: " + athena_output_location + "\n")

def lambda_handler(event, context):
    """Start execution of related queries"""
    
    date_run = os.environ.get('ev_date_run')
    
    print("Running Athena queries for this date: " + date_run + "\n")
    
    # Evaluate the date in environment variable "date_run", to determine if it's a manual or a scheduled invocation.
    # Return the parts of the date ("year", "month" and "day").
    # NOTE: in the case of scheduled invocation, get statistics from the previous day.
    if (date_run == '0000/00/00'):
        previous_day = datetime.now() - timedelta(days=1)
        year_part = str(previous_day.year)
        month_part = str(previous_day.month).rjust(2, '0')
        day_part = str(previous_day.day).rjust(2, '0')
    else:
        try:
            current_day = datetime.strptime(date_run, '%Y/%m/%d')
            year_part = str(current_day.year)
            month_part = str(current_day.month).rjust(2, '0')
            day_part = str(current_day.day).rjust(2, '0')
        except Exception as e:
            print(e)
            print("Error formating manual running date provided!")
            raise e
    
    # Calculating Total Electricity metered by hour, in one day, per customer
    try:
        out_electricity_by_hour = athena.start_query_execution(
            QueryString="SELECT cust.customerid, (cast(cust.sendorid as varchar) || '#' || iot.year || '-' || iot.month || '-' || iot.day || 'T' || iot.hourcollected) sensorid_hour, iot.kwh total_kwh " +
                            "FROM iot_electricity_metering iot " +
                            "INNER JOIN customer_meter_sensor cust " +
                            "ON (iot.sendorid = cust.sendorid) " +
                            "WHERE year = '" + year_part + "' " + 
                              "AND month = '" + month_part + "' " +
                              "AND day = '" + day_part + "' " +
                            "ORDER BY 1, 2",
            QueryExecutionContext={
                'Database': 'iotanalyticsdb',
                'Catalog': 'AwsDataCatalog'
            },
            ResultConfiguration={
                'OutputLocation': athena_output_location + "electricity_by_period/",
                'EncryptionConfiguration': {
                    'EncryptionOption': 'SSE_S3'
                }
            }
        )
        print("Total Electricity metered by hour => Query Execution ID: " + out_electricity_by_hour['QueryExecutionId'])
    except Exception as e:
        print(e)
        print("Total Electricity metered by hour => Error executing Athena query!")
        raise e
        
    # Calculating Total Electricity metered by day, per customer
    try:
        out_electricity_by_day = athena.start_query_execution(
            QueryString="SELECT cust.customerid, (cast(cust.sendorid as varchar) || '#' || iot.year || '-' || iot.month || '-' || iot.day) sensorid_day, ROUND(SUM(iot.kwh), 2) total_kwh " +
                            "FROM iot_electricity_metering iot " +
                            "INNER JOIN customer_meter_sensor cust " +
                            "ON (iot.sendorid = cust.sendorid) " +
                            "WHERE year = '" + year_part + "' " +
                              "AND month = '" + month_part + "' " +
                              "AND day = '" + day_part + "' " +
                            "GROUP BY cust.customerid, (cast(cust.sendorid as varchar) || '#' || iot.year || '-' || iot.month || '-' || iot.day) " +
                            "ORDER BY 1, 2",
            QueryExecutionContext={
                'Database': 'iotanalyticsdb',
                'Catalog': 'AwsDataCatalog'
            },
            ResultConfiguration={
                'OutputLocation': athena_output_location + "electricity_by_period/",
                'EncryptionConfiguration': {
                    'EncryptionOption': 'SSE_S3'
                }
            }
        )
        print("Total Electricity metered by day => Query Execution ID: " + out_electricity_by_day['QueryExecutionId'])
    except Exception as e:
        print(e)
        print("Total Electricity metered by day => Error executing Athena query!")
        raise e
    
    # If this day is the last of the month, calculate Total Electricity metered by month, per customer
    if (day_part == str(calendar.monthrange(int(year_part), int(month_part))[1])):
        try:
            out_electricity_by_month = athena.start_query_execution(
                QueryString="SELECT cust.customerid, (cast(cust.sendorid as varchar) || '#' || iot.year || '-' || iot.month) sensorid_month, ROUND(SUM(iot.kwh), 2) total_kwh " +
                                "FROM iot_electricity_metering iot " +
                                "INNER JOIN customer_meter_sensor cust " +
                                "ON (iot.sendorid = cust.sendorid) " +
                                "WHERE year = '" + year_part + "' " +
                                  "AND month = '" + month_part + "' " +
                                "GROUP BY cust.customerid, (cast(cust.sendorid as varchar) || '#' || iot.year || '-' || iot.month) " +
                                "ORDER BY 1, 2",
                QueryExecutionContext={
                    'Database': 'iotanalyticsdb',
                    'Catalog': 'AwsDataCatalog'
                },
                ResultConfiguration={
                    'OutputLocation': athena_output_location + "electricity_by_period/",
                    'EncryptionConfiguration': {
                        'EncryptionOption': 'SSE_S3'
                    }
                }
            )
            print("Total Electricity metered by month => Query Execution ID: " + out_electricity_by_month['QueryExecutionId'])
        except Exception as e:
            print(e)
            print("Total Electricity metered by month => Error executing Athena query!")
            raise e
