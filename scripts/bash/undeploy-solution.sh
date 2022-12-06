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
# Undeploy solution environment, created by bash shell
# script "./deploy-solution.sh"
# (1) Disable server access logging on deployed S3 buckets
# (2) Drop database "iotanalyticsdb" and its external tables
# "iot-analytic-bucket-<AWS account ID>-<AWS Region>"
# (3) Delete Athena Workgroup created 
# (4) Delete objects on deployed S3 buckets
# (5) Undeploy AWS SAM application "sam-iot-analytics"
#********************************************************
# Execution:
# -----------
# 
# > ./undeploy-solution.sh
#********************************************************

# Disable server access logging on deployed S3 buckets
# --------------------------------------------------------
echo "###########################################################"
echo " Disabling server access logging on deployed S3 buckets..."
echo "###########################################################"

# Get destination bucket name
BUCKET_NAME=`aws s3api list-buckets --query "Buckets[].Name" --output=yaml | grep iot-analytic-bucket | cut -d " " -f 2`

# Get Athena ouput bucket name
ATHENA_OUTPUT_BUCKET=`aws s3api list-buckets --query "Buckets[].Name" --output=yaml | grep iot-athena-results | cut -d " " -f 2`

# Disable server access logging
aws s3api put-bucket-logging --bucket ${BUCKET_NAME} --bucket-logging-status {}
aws s3api put-bucket-logging --bucket ${ATHENA_OUTPUT_BUCKET} --bucket-logging-status {}
# --------------------------------------------------------

# Remove Athena objects
# --------------------------------------------------------
# Drop the database
echo "######################################"
echo ' Droping database "iotanalyticsdb"...'
echo "######################################"

aws athena start-query-execution \
    --query-string "drop database if exists iotanalyticsdb cascade" \
    --work-group "DDL_Group"

# Delete Athena Workgroup
echo "######################################"
echo ' Deleting Athena Workgroup created...'
echo "######################################"
aws athena delete-work-group --work-group DDL_Group --recursive-delete-option
# --------------------------------------------------------

# Deleting the objects on deployed S3 buckets
# --------------------------------------------------------
echo "############################################"
echo " Deleting objects on deployed S3 buckets..."
echo "############################################"

# Get log bucket name
LOG_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[].Name" --output=yaml | grep log-bucket | cut -d " " -f 2`

# Deleting objects on S3 buckets
aws s3 rm s3://${BUCKET_NAME} --recursive
aws s3 rm s3://${ATHENA_OUTPUT_BUCKET} --recursive
aws s3 rm s3://${LOG_BUCKET_NAME} --recursive
# --------------------------------------------------------

# Undeploy the AWs SAM-based solution, using the AWS SAM CLI
# --------------------------------------------------------
echo "#####################################################"
echo " Undeploying AWS SAM application sam-iot-analytics..."
echo "#####################################################"

sam delete --stack-name sam-iot-analytics
