PROFILE :=
EVENT :=
DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Helper functions
FILTER_OUT = $(foreach v,$(2),$(if $(findstring $(1),$(v)),,$(v)))
TITLE_CASE = $(shell echo $1 | cut -c1 | tr '[[:lower:]]' '[[:upper:]]')$(shell echo $1 | cut -c2-)

.PHONY: help clean dist create/% run/% test test/% deploy deploy/% _check-vers _check-code-bucket api _check-alias _check-artifact-bucket _check-aws-env _check-size connect
.SILENT: help deploy

help:
	echo "HELLO BIRDIE LAMBDA/API MAKEFILE FUNCTIONS"
	echo "----------------------------------------------------------"
	echo "(Add VERBOSE=1 for verbose output)"
	echo "----------------------------------------------------------"
	echo "Run a function:         make run/FUNCTION [EVENT=filename]"
	echo "Run all tests:          make test"
	echo "Run a specific test:    make test/TEST"
	echo "----------------------------------------------------------"
	echo "Package all functions:  make dist"
	echo "Package a function:     make dist/{FUNCTION}.zip"
	echo "Deploy a function:      make deploy/FUNCTION [ENV=hb-sandbox|hb-prod]"
	echo "Setup environment:      make env [ENV=hb-sandbox|hb-prod]"
	echo "Set function MEM size:  make setmem/FUNCTION SIZE=[size]"
	echo "----------------------------------------------------------"
	echo "Deploy an API to AWS:   make api VERS=<version> [UPDATE=<api_id>] [STAGE=<stage_name>] [ALIAS=<LAMBDA_ALIAS>] [CREATE=1] [NOPERMS=1]"
	echo "                        Load the proper file from the '/swagger' folder using the VERS provided. Processes the file to inject AWS Region, Lambda ALIAS and AWS Account ID."
	echo "                        If UPDATE is provided: It will update an existing API directly the ID provided"
	echo "                        ALIAS is mandatory when updating and reference the Lambda function ALIAS"
	echo "                        If CREATE is provided: It will create a new API"
	echo "                        If NOPERMS is provided then the Lambda permissions won't be set"
	echo "----------------------------------------------------------"

all: dist

api: .env _check-vers _check-alias
	$(eval SRC_FILE = ./swagger/api-$(VERS).yaml)
	$(eval DST_FILE = _api-$(VERS).yaml)
	cp ${SRC_FILE} ${DST_FILE}

# We replace %stuff% in the API YAML files with ENV variables values
	sed -i "s/%AWS_ACCOUNT%/${AWS_ACCOUNT}/g" ${DST_FILE}
	sed -i "s/%AWS_REGION%/${AWS_DEFAULT_REGION}/g" ${DST_FILE}

	echo "Using Lambda ALIAS: ${ALIAS}"
	sed -i "s/%ALIAS%/${ALIAS}/g" ${DST_FILE}

# If We activate the UPDATE variable, we can update the API Getway API directly
# We then excute AWS tool to import file in API Gateway
	@if [ -n "${UPDATE}" ]; then \
		echo "Updating API: ${UPDATE}"; \
		if [ ! -n "${NOPERMS}" ]; then \
			./scripts/lambda_set_perms.sh ${UPDATE} ${ALIAS}; \
		fi; \
		aws apigateway put-rest-api --region ${AWS_DEFAULT_REGION} --rest-api-id ${UPDATE} --mode merge --fail-on-warnings --body 'file://${DST_FILE}' ; \
		if [ -n "${STAGE}" ]; then \
			aws apigateway create-deployment --region ${AWS_DEFAULT_REGION} --rest-api-id ${UPDATE} --stage-name ${STAGE} ; \
		fi; \
	elif [ -n "${CREATE}" ]; then \
		echo "Creating new API"; \
		aws apigateway import-rest-api --region ${AWS_DEFAULT_REGION} --fail-on-warnings --body 'file://${DST_FILE}' ; \
	fi;

run/%: .env src/%/* build/setup.cfg $(wildcard lib/**/*)
	PYTHONPATH="${DIR}build" python3 "${DIR}run.py" $(if $(VERBOSE),--verbose) $* $(if $(EVENT),"$(EVENT)")

setmem/%: _check-size
	aws $(if ${PROFILE},--profile ${PROFILE},) lambda update-function-configuration \
        --function-name $* \
        --memory-size ${SIZE}

dist: $(addprefix dist/,$(addsuffix .zip,$(call FILTER_OUT,__init__, $(notdir $(wildcard src/*))))) .env
dist/%.zip: src/%/* build/setup.cfg $(wildcard lib/**/*) .env
	cd build && zip -r -q ../$@ *
	zip -r -q $@ lib
	cd $(<D) && zip -r -q ../../$@ *

build/setup.cfg: requirements.txt
	find build/ -mindepth 1 -not -name setup.cfg -delete
	pip3 install -r $^ -t $(@D)
	touch $@
	-touch build/.gitkeep

deploy: $(addprefix deploy/,$(call FILTER_OUT,__init__, $(notdir $(wildcard src/*)))) .env
deploy/%: _check-aws-env _check-alias _check-artifact-bucket templates/dist dist/%.zip
	aws cloudformation package --template-file templates/$*.template  --s3-bucket ${AWS_BUCKET_ARTIFIFACT} --output-template-file packaged-templates/$*-packaged.json
	aws cloudformation deploy --template-file packaged-templates/$*-packaged.json --stack-name $* --capabilities CAPABILITY_IAM --parameter-overrides Env=${ENV}
	./scripts/lambda_autoalias.sh $* ${ALIAS} $(if ${PROFILE},--profile ${PROFILE},)

templates/dist:
	ln -s  $(PWD)/dist $(PWD)/templates/dist

clean:
	-$(RM) -rf dist/*
	-$(RM) -rf build/*
	-$(RM) -f .env
	-touch build/.gitkeep

.env: _check-aws-env _check-code-bucket
	aws $(if ${PROFILE},--profile ${PROFILE},) s3 cp s3://${AWS_BUCKET_CODE}/${AWSENV_NAME}_creds ./lib/env.py
	cp ./lib/env.py .env

_check-vers:
ifndef VERS
	@echo "You must provide a Version for your API to deploy!";
	@echo "e.g: make api VERS=0.6";
	@echo "We pick the proper file in ./swagger/api-$VERSION.yaml";
	@false;
endif

_check-alias:
ifndef ALIAS
	@echo "You must provide an ALIAS for your Lambda and to your API";
	@echo "This is used so you can have multiple lambda versions so you can have multiple APIs in parallel";
	@false;
endif

_check-size:
ifndef SIZE
	@echo "You must provide a size for your function! See lambda console and function configuration for list of memory.";
	@echo "e.g: make setmem/<function> SIZE=512";
	@false;
endif

_check-aws-env:
ifndef AWSENV_NAME
	@echo "No AWSENV_NAME environment variable declared. Set it up and retry.";
	@echo "This is used to pull the credential file from the correct bucket. e.g: hb-sandbox, hb-prod";
	@false;
endif

_check-code-bucket:
ifndef AWS_BUCKET_CODE
	@echo "No AWS_BUCKET_CODE environment variable declared. Set it up and retry.";
	@echo "This is used to know where your credential files are for .env";
	@false;
endif

_check-artifact-bucket:
ifndef AWS_BUCKET_ARTIFACT
	@echo "No AWS_BUCKET_ARTIFACT environment variable declared. Set it up and retry.";
	@echo "This is used to know where to store your CloudFormation template to deploy your Lambda";
	@false;
endif

