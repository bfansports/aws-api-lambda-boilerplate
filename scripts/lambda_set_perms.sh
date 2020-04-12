#!/bin/bash

API_ID=$1
ALIAS=$2

if [ ! -n "${AWS_ACCOUNT}" ];
then
    echo 'AWS_ACCOUNT env variable not set!'
    exit 1
fi

echo "START setting lambda permissions"
for i in `ls src | egrep -v '_init_|endpoint'`;
do
    echo "Set permission for Lambda: ${i}"
    aws lambda add-permission --function-name arn:aws:lambda:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT}:function:${i}:${ALIAS} \
        --source-arn "arn:aws:execute-api:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT}:${API_ID}/*" \
        --statement-id ${i} \
        --principal apigateway.amazonaws.com \
        --action lambda:InvokeFunction 2>&1 | grep -v ResourceConflictException
done

echo "DONE"
echo "-----------------------------------------------------------------------------"
