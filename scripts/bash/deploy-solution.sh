#!/bin/bash
#********************************************************
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#********************************************************
# Blog Post Project.....: Iot Analytical System
#********************************************************
# Script Purpose: 
# ---------------
# 
# Setup solution environment, running several 
# configuration tasks, in the following order:
#
# (1) Deploy the AWs SAM-based solution
# (2) Upload CSV file with customer electricity meter 
# data to S3 bucket 
# "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
# (3) Upload CSV files with IoT electricity metering data 
# to S3 bucket 
# "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
# (4) Create database "iotanalyticsdb" on 
# AWS Glue Data Catalog.
# (5) Create external tables "customer_meter_sensor" and 
# "iot_electricity_metering" on AWS Glue Data Catalog.
# (5) Update the partitions on external table 
# "iot_electricity_metering"
#********************************************************
# Execution:
# -----------
# 
# > ./deploy-solution.sh
#********************************************************
# Set relative directory paths, to be used througout the script.
export DATASET_PATH=../../datasets
export SAM_PATH=../../sam-iot-analytics

# Deploy the AWs SAM-based solution, using the AWS SAM CLI
# --------------------------------------------------------
echo "################################################################"
echo " Building and deploying AWS SAM application sam-iot-analytics..."
echo "################################################################"

sam build --use-container \
    --template ${SAM_PATH}/template.yaml \
    --build-dir ${SAM_PATH}/.aws-sam/build/

sam deploy --stack-name sam-iot-analytics \
    --template ${SAM_PATH}/.aws-sam/build/template.yaml \
    --guided --capabilities CAPABILITY_NAMED_IAM
# --------------------------------------------------------

# Upload CSV file with customer electricity meter data to 
# S3 bucket "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
# --------------------------------------------------------------
echo "##############################################################################"
echo " Uploading CSV file with customer electricity meter to Data Lake S3 bucket..."
echo "##############################################################################"

# Get destination bucket name
BUCKET_NAME=`aws s3api list-buckets --query "Buckets[].Name" --output=yaml | grep iot-analytic-bucket | cut -d " " -f 2`

# Copy CSV file with customer data to S3 bucket "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
aws s3 cp ${DATASET_PATH}/customer_meter_sensor/customer_meter_sensor.csv \
    s3://${BUCKET_NAME}/customer_meter_sensor/customer_meter_sensor.csv
# --------------------------------------------------------------

# Upload CSV files with IoT electricity metering to S3 bucket 
# "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
# --------------------------------------------------------------
echo "#############################################################################"
echo " Uploading CSV files with IoT electricity metering to Data Lake S3 bucket..."
echo "#############################################################################"

# Get list of sub-directories from dataset main directory, based on specific dates
DIR_LIST=`ls ${DATASET_PATH}/iot_electricity_metering`

# Run through DIR_LIST in a loop
for DATE_DIR in ${DIR_LIST}
do 
    # Extract YEAR, MONTH and DAY components from each date sub-directory.
    # These date components will be used to create S3 partitions
    YEAR=`echo ${DATE_DIR} | cut -d "-" -f 1`
    MONTH=`echo ${DATE_DIR} | cut -d "-" -f 2`
    DAY=`echo ${DATE_DIR} | cut -d "-" -f 3`
    
    # Copy CSV files from each local dataset date sub-directory 
    # to specific partitions on S3 bucket "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
    aws s3 cp ${DATASET_PATH}/iot_electricity_metering/${DATE_DIR} \
        s3://${BUCKET_NAME}/iot_electricity_metering/year=${YEAR}/month=${MONTH}/day=${DAY}/ --recursive --include "*.csv"
done
# --------------------------------------------------------------

# Create an Athena Workgroup configuration to run Athena queries 
# in this deploy script
# --------------------------------------------------------------
echo "#####################################################################"
echo " Creating an Athena Workgroup configuration to run Athena queries..."
echo "#####################################################################"

# Get Athena ouput bucket name
ATHENA_OUTPUT_BUCKET=`aws s3api list-buckets --query "Buckets[].Name" --output=yaml | grep iot-athena-results | cut -d " " -f 2`

# Create Athena workgroup
aws athena create-work-group \
    --name DDL_Group \
    --configuration ResultConfiguration={OutputLocation="s3://${ATHENA_OUTPUT_BUCKET}/ddl_output/"}
# --------------------------------------------------------------

# Create database "iotanalyticsdb" on AWS Glue Data Catalog
# --------------------------------------------------------------
echo "##############################################################"
echo ' Create database "iotanalyticsdb" on AWS Glue Data Catalog...'
echo "##############################################################"

aws athena start-query-execution \
    --query-string "create database if not exists iotanalyticsdb" \
    --work-group "DDL_Group"
# --------------------------------------------------------------

# Create external tables "customer_meter_sensor" and 
# "iot_electricity_metering" on AWS Glue Data Catalog
# --------------------------------------------------------------
# Create external table "customer_meter_sensor"
echo "##################################################"
echo ' Create external table "customer_meter_sensor"...'
echo "##################################################"

aws athena start-query-execution \
    --query-string "CREATE EXTERNAL TABLE customer_meter_sensor(
                        customerid bigint,
                        sendorid bigint,
                        sensorgroup string)
                    ROW FORMAT DELIMITED 
                      FIELDS TERMINATED BY ',' 
                    STORED AS INPUTFORMAT 
                      'org.apache.hadoop.mapred.TextInputFormat' 
                    OUTPUTFORMAT 
                      'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
                    LOCATION
                      's3://${BUCKET_NAME}/customer_meter_sensor/'
                    TBLPROPERTIES ('skip.header.line.count'='1')" \
    --work-group "DDL_Group" \
    --query-execution-context Database=iotanalyticsdb,Catalog=AwsDataCatalog

# Create external table "iot_electricity_metering"
echo "#####################################################"
echo ' Create external table "iot_electricity_metering"...'
echo "#####################################################"

aws athena start-query-execution \
    --query-string "CREATE EXTERNAL TABLE iot_electricity_metering(
                          sendorid bigint, 
                          voltage bigint, 
                          \`current\` bigint, 
                          frequency bigint, 
                          kwh double, 
                          hourcollected string)
                        PARTITIONED BY ( 
                          year string, 
                          month string, 
                          day string)
                        ROW FORMAT DELIMITED 
                          FIELDS TERMINATED BY ',' 
                        STORED AS INPUTFORMAT 
                          'org.apache.hadoop.mapred.TextInputFormat' 
                        OUTPUTFORMAT 
                          'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
                        LOCATION
                          's3://${BUCKET_NAME}/iot_electricity_metering/'
                        TBLPROPERTIES ('skip.header.line.count'='1')" \
    --work-group "DDL_Group" \
    --query-execution-context Database=iotanalyticsdb,Catalog=AwsDataCatalog
# --------------------------------------------------------------

# Update the partitions on external table "iot_electricity_metering"
# --------------------------------------------------------------
echo "#####################################################################"
echo ' Updating partitions on external table "iot_electricity_metering"...'
echo "#####################################################################"

aws athena start-query-execution \
    --query-string "MSCK REPAIR TABLE iot_electricity_metering" \
    --work-group "DDL_Group" \
    --query-execution-context Database=iotanalyticsdb,Catalog=AwsDataCatalog
# --------------------------------------------------------------
