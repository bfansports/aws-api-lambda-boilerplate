#!/bin/bash

FUNC=$1
ALIAS=$2
PROFILE=$3

VERSION=$(aws lambda list-versions-by-function \
    --function-name ${FUNC} \
    --region ${AWS_DEFAULT_REGION} \
    | grep Version | awk -F':' '{print $2}' | awk -F'"' '{print $2}')

echo "LAMBDA VERSION: ${VERSION}"

OUT=`aws ${PROFILE} lambda create-alias \
      --function-name ${FUNC} \
      --name ${ALIAS} \
      --function-version ${VERSION} 2>&1 | grep 'An error occurred'`
CODE=$?

if [ ${CODE} -eq 0 ]; then
    OUT=`aws ${PROFILE} lambda update-alias \
      --function-name ${FUNC} \
      --name ${ALIAS} \
      --function-version ${VERSION}`
    echo "ALIAS UPDATED: ${ALIAS}"
else
    echo "ALIAS CREATED: ${ALIAS}"
fi

echo "DONE"
echo "-----------------------------------------------------------------------------"
