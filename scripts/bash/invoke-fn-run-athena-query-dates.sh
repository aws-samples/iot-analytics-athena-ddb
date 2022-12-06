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
# Invoke locally Lambda function "fn-run-athena-query",
# with several calls, using different combinations of 
# environment variable "ev_date_run", to simulate daily
# invocations of this function.
#********************************************************
# Execution:
# -----------
# 
# > ./invoke-fn-run-athena-query-dates.sh
#********************************************************
# Disable paging with "less" command
export AWS_PAGER=""
# Set AWS SAM application path, to be used througout the script.
export SAM_PATH=../../sam-iot-analytics

# Get destination bucket name
BUCKET_NAME=`aws s3api list-buckets --query "Buckets[].Name" --output=yaml | grep iot-athena-results | cut -d " " -f 2`

# Setting the initial date to process the simulation (January 1st, 2022)
DAY_JAN=1

# Run through each day of January/2022, in a loop
while [ $DAY_JAN -le 31 ]
do 
    # Get day part of the date in DAY_JAN environment variable
    DAY_PART=$( [ $((DAY_JAN - 10)) -lt 0 ] && echo "0$DAY_JAN" || echo "$DAY_JAN" )
    
    # Create an environment variable file for "sam local invoke"
    echo "{" > ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    echo "  \"RunAthenaQueryFunction\": {" >> ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    echo "    \"ev_athena_output_location\": \"s3://${BUCKET_NAME}/\"," >> ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    echo "    \"ev_date_run\": \"2022/01/${DAY_PART}\"" >> ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    echo "  }" >> ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    echo "}" >> ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    
    # Invoke Lambda function "fn-run-athena-query" locally, overriding 
    # the environment variables "ev_date_run" and "ev_athena_output_location" 
    # with the value of current JSON file, which name is referenced by DAY_PART iterator.
    sam local invoke "RunAthenaQueryFunction" \
        --template ${SAM_PATH}/.aws-sam/build/template.yaml \
        --env-vars ${SAM_PATH}/env-vars/jan-day-run-${DAY_PART}.json
    
    # Goto next date of January/2022
    DAY_JAN=$((DAY_JAN + 1))
done

# Return original values of environment variables "ev_date_run" and "ev_athena_output_location",
# for Lambda function "fn-run-athena-query" 
aws lambda update-function-configuration --function-name fn-run-athena-query \
    --environment "Variables={ev_date_run=0000/00/00,ev_athena_output_location= s3://${BUCKET_NAME}/}" \
    --query '[{FunctionName: FunctionName}, {Runtime: Runtime}, {Environment: Environment}]'
