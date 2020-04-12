# Swagger file

Our swagger file must be compatible with API Gateway specifications:

   * https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-open-api.html
   * https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions.html

## Special actions

The Makefile injects on the fly several environment variables into the the file before processing in it:

   * %AWS_REGION%
   * %AWS_ACCOUNT%
   * %ALIAS%

Edit the Makefile if you need to do more replacements

