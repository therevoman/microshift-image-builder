SHELL=bash

ENVFILE ?= .env-${PROJECT_NAME}
ENVFILE_EXAMPLE ?= ${CURRENT_DIR}/template/.env-example

RHEL_ISO_FILENAME ?= rhel-9.3-x86_64-boot.iso
CURRENT_DIR := $(shell pwd)
TEMPLATE_DIR := ${CURRENT_DIR}/templates
TMP_DIR ?= ${CURRENT_DIR}/tmp/${PROJECT_NAME}
#BUILDID ?= ""

OSTREE_REPO_PATH ?= /mnt/redhat/ostree
OSTREE_REPO_URL ?= http://localhost/ostree/repo
OSTREE_BRANCH ?= DEV
OSTREE_REF ?= rhel/9/x86_64/edge

BLUEPRINT_FILENAME ?= ${PROJECT_NAME}.toml
BLUEPRINT_TEMPLATE ?= ${BLUEPRINT_FILENAME}.tpl
KICKSTART_FILENAME ?= ${PROJECT_NAME}.ks
KICKSTART_SHORT_FILENAME ?= ks.cfg
KICKSTART_TEMPLATE ?= ${KICKSTART_FILENAME}.tpl
HTTPD_PATH ?= /mnt/hosts/microshift
SSH_KEY_PATH ?= $$HOME/.ssh/
SSH_USER ?= core
ADMIN_SSH_KEY ?= id_rsa_admin.pub
USER_SSH_KEY ?= id_rsa.pub
ADMIN_SSH_KEY_CONTENTS ?= $(shell cat ${SSH_KEY_PATH}${USER_SSH_KEY})
USER_SSH_KEY_CONTENTS ?= $(shell cat ${SSH_KEY_PATH}${ADMIN_SSH_KEY})
ADMIN_SSH_PASSWORD ?= $6$zj09HH0FIV8eIZ9D$MZaEWeIuOuGzcvk37cFUv6AN6.0IUH35HdCRGsHFsa9d5gLeCQXGEfoaDcg3XWJWGwHNs1MceXJIJ/YnJlzz4. # notsecret
USER_SSH_PASSWORD ?= $6$zj09HH0FIV8eIZ9D$MZaEWeIuOuGzcvk37cFUv6AN6.0IUH35HdCRGsHFsa9d5gLeCQXGEfoaDcg3XWJWGwHNs1MceXJIJ/YnJlzz4. # notsecret
ROOT_SSH_PASSWORD ?= $6$zj09HH0FIV8eIZ9D$MZaEWeIuOuGzcvk37cFUv6AN6.0IUH35HdCRGsHFsa9d5gLeCQXGEfoaDcg3XWJWGwHNs1MceXJIJ/YnJlzz4. # notsecret
PULL_SECRET_DIR ?= $$HOME/.config/
PULL_SECRET_FILE ?= pull-secret.json
PULL_SECRET ?= $(shell cat ${PULL_SECRET_DIR}/${PULL_SECRET_FILE})

# found in https://stackoverflow.com/questions/44628206/how-to-load-and-export-variables-from-an-env-file-in-makefile
# stopped using 2024/08/14 because make $(shell cat file.txt) by default strips all newlines
# instead use `source <envfile>`
#ifneq (,$(wildcard ${ENVFILE}))
#    include ${ENVFILE}
#    export
#endif

define newline # a literal \n


endef

# keep ifdef left justified even though its part of check-config
ifndef PROJECT_NAME
    $(error ❗ERROR project name not detected. Ensure env vars are exported and make is prefixed with PROJECT_NAME=<myproject>.)
endif


.PHONY: create-temp-dir clean create update blueprint custom-blueprint kickstart deploy-kickstart push-blueprint build-new-image build-update-image start-build start-update-build wait-for-build create-temp-buildfolder extract-image create-repo update-repo cleanup-temp-buildfolder generate-password clean-all generate-example add-sources delete-sources

default: help

## Show configuration variables
showconfig: p-SHELL p-PROJECT_NAME p-ENVFILE p-RHEL_ISO_FILENAME p-CURRENT_DIR p-TEMPLATE_DIR p-TMP_DIR p-BUILDID p-OSTREE_REPO_PATH p-OSTREE_REPO_URL p-OSTREE_BRANCH p-BLUEPRINT_FILENAME p-BLUEPRINT_TEMPLATE p-KICKSTART_FILENAME p-KICKSTART_SHORT_FILENAME p-KICKSTART_TEMPLATE p-HTTPD_PATH p-SSH_KEY_PATH p-SSH_USER p-ADMIN_SSH_KEY p-USER_SSH_KEY p-ADMIN_SSH_KEY_CONTENTS p-USER_SSH_KEY_CONTENTS p-PULL_SECRET_DIR p-PULL_SECRET_FILE p-PULL_SECRET 

p-%:
	@echo '$*=$(subst ','\'',$(subst $(newline),\n,$($*)))'

# make sure the unique tmp folder exists, run in .PHONY
create-temp-dir: check-config
	mkdir -p ${TMP_DIR}

## Main target for creating new ostree repo
create: blueprint kickstart push-blueprint build-new-image create-temp-buildfolder extract-image create-repo deploy-kickstart
	echo BUILDID=${BUILDID}

## Main target for updating ostree repo from new template.
update: increment-version blueprint kickstart push-blueprint build-update-image create-temp-buildfolder extract-image update-repo cleanup-temp-buildfolder
	echo BUILDID=${BUILDID}

# use sourced IMAGE_VERSION to update the IMAGE_VERSION in the envfile
increment-version:
	$(if $(value IMAGE_VERSION),, $(eval $(error ❗ERROR IMAGE_VERSION project name not detected. Ensure env vars are sourced and make is prefixed with PROJECT_NAME=<myproject>.)))
	$(eval IMAGE_VERSION=$(shell echo ${IMAGE_VERSION} | awk -F. -v OFS=. '{$$NF++; print}'))
	@echo NEW_IMAGE_VERSION=${IMAGE_VERSION}
	$(shell sed -i 's/IMAGE_VERSION=.*/IMAGE_VERSION=${IMAGE_VERSION}/g' .env-${PROJECT_NAME})
# Generate custom blueprint file ${BLUEPRINT_FILENAME}.toml from ${BLUEPRINT_FILENAME}.toml.tpl
blueprint: check-config create-temp-dir custom-blueprint 

check-config:
	@echo check-config
	@echo PROJECT_NAME=${PROJECT_NAME}
	$(info Checking if PROJECT_NAME environment variable is set)
	$(if $(value PROJECT_NAME),, $(eval $(error ❗ERROR PROJECT_NAME project name not detected. Ensure env vars are sourced and make is prefixed with PROJECT_NAME=<myproject>.)))


# the error has to be wrapped in an eval otherwise it will be processed every time the makefile is processed, basically useless.
check-buildid:
## https://superuser.com/questions/1752412/variables-not-being-set-in-makefile
	@echo check-buildid $$BUILDID
	$(if $(value BUILDID),, $(eval $(error ❗ERROR BUILDID is not defined.  This should be returned by "composer-cli". Check for errors in Image Builder.)))

custom-blueprint: ${BLUEPRINT_TEMPLATE}

${PROJECT_NAME}.toml.tpl: ${PROJECT_NAME}.toml

${PROJECT_NAME}.toml:
	cat ${TEMPLATE_DIR}/${BLUEPRINT_TEMPLATE} | envsubst > ${TMP_DIR}/${BLUEPRINT_FILENAME}

# Generate custom kickstart file ${KICKSTART_FILENAME}.toml from ${KICKSTART_FILENAME}.toml.tpl
kickstart: create-temp-dir ${KICKSTART_TEMPLATE}

${PROJECT_NAME}.ks.tpl: ${PROJECT_NAME}.ks

${PROJECT_NAME}.ks:
	cat ${TEMPLATE_DIR}/${KICKSTART_TEMPLATE} | envsubst > ${TMP_DIR}/${KICKSTART_FILENAME}

deploy-kickstart: kickstart
	cp ${TMP_DIR}/${KICKSTART_FILENAME} ${HTTPD_PATH}/${KICKSTART_SHORT_FILENAME}

push-blueprint: check-config
	composer-cli blueprints push ${TMP_DIR}/${BLUEPRINT_FILENAME};

build-new-image: start-build check-buildid wait-for-build

build-update-image: start-update-build check-buildid wait-for-build

start-build: check-buildid
	$(eval BUILDID=$(shell composer-cli compose start-ostree ${PROJECT_NAME} edge-commit | awk '{print $$2}'))
	@echo new BUILDID is ${BUILDID}

start-update-build: 
	@echo "composer-cli compose start-ostree ${PROJECT_NAME} edge-commit --url ${OSTREE_REPO_URL} --ref ${OSTREE_REF} | awk '{print $$ 2}'"

	$(eval BUILDID=$(shell composer-cli compose start-ostree ${PROJECT_NAME} edge-commit --url ${OSTREE_REPO_URL} --ref ${OSTREE_REF} | grep Compose | awk '{print $$2}'))
	@echo "update BUILDID is '${BUILDID}'"

# Simple look to check status of image builder with Make
wait-for-build: check-buildid
	@echo wait for build ${BUILDID} to stop RUNNING
	set -e; \
	while [[ "$$(composer-cli compose status | grep ${BUILDID} | awk '{print $$2}')" == 'RUNNING' ]]; do echo RUNNING $$(date); sleep 30; done;
	@echo done waiting;

create-temp-buildfolder: check-buildid
	@echo BUILDID=${BUILDID}
	#rm -rf ${TMP_DIR}/${BUILDID}
	mkdir -p ${TMP_DIR}/${BUILDID}

extract-image: create-temp-buildfolder
	composer-cli compose image ${BUILDID} --filename ${TMP_DIR}/${BUILDID}/
	tar -xf ${TMP_DIR}/${BUILDID}/${BUILDID}-commit.tar -C ${TMP_DIR}/${BUILDID}/

# Removes and creates a clean repository folder
create-repo: check-buildid
	rm -rf ${OSTREE_REPO_PATH}/repo
	tar -xf ${TMP_DIR}/${BUILDID}/${BUILDID}-commit.tar -C ${OSTREE_REPO_PATH}/

# Updates repository folder with files from previous build
update-repo: check-buildid
	ostree --repo=${OSTREE_REPO_PATH}/repo pull-local ${TMP_DIR}/${BUILDID}/repo

## return an encrypted password
generate-password:
	openssl passwd -6

## Generate sample .env file and templates
generate-example:
	@echo Creting custom .env-example file.  Verify templates for kickstart and image builder in "${TEMPLATE_DIR}"
	cp templates/env-example ${CURRENT_DIR}/.env-example
	@echo Create new repository with the command "sudo PROJECT_NAME=example make create"
	@echo Update repository with the command "sudo PROJECT_NAME=example make update"


# Generate files from repo source templates
reposources := $(wildcard ${TEMPLATE_DIR}/repofiles/*.toml.tpl)

repofiles: $(reposources)
	echo templatename $(notdir $(basename $^))
	mkdir -p ${TMP_DIR}/repofiles/
	for file in $(notdir $(basename $^)) ; do \
		cat ${TEMPLATE_DIR}/repofiles/$${file}.tpl | envsubst > ${TMP_DIR}/repofiles/$${file} ; \
	done


## Remove custom composer sources
delete-sources:
	-composer-cli sources delete local-rhel9-baseos
	-composer-cli sources delete local-rhel9-appstream
	-composer-cli sources delete local-rhel9-fast-datapath
	-composer-cli sources delete local-ocp-4.15-for-rhel9
	-composer-cli sources delete local-ocp-4.16-for-rhel9
	-composer-cli sources delete local-rhceph-7-tools-for-rhel-9
	-composer-cli sources delete local-revoweb-for-rhel9
	-composer-cli sources delete local-gitops-1.13-for-rhel-9
	sudo systemctl restart osbuild-composer.service

## Add custom composer sources
add-sources: repofiles
	echo run 'composer-cli distros list' to see distros
	composer-cli sources add ${TMP_DIR}/repofiles/local-rhel9-baseos.toml
	composer-cli sources add ${TMP_DIR}/repofiles/local-rhel9-appstream.toml
	composer-cli sources add ${TMP_DIR}/repofiles/local-rhel9-fast-datapath.toml
	composer-cli sources add ${TMP_DIR}/repofiles/local-rhel9-rhocp-4.16.toml
	composer-cli sources add ${TMP_DIR}/repofiles/local-rhceph-7-tools-for-rhel.toml
	composer-cli sources add ${TMP_DIR}/repofiles/local-revoweb-for-rhel9.toml
	composer-cli sources add ${TMP_DIR}/repofiles/local-gitops-1.13-for-rhel-9.toml
	sudo systemctl restart osbuild-composer.service

## Clean up the tmp folder created for PROJECT_NAME
clean: check-config
	rm -rf \
		${TMP_DIR}

# Used internally to clean up folder of build BUILDID
cleanup-temp-buildfolder: check-buildid
	rm -rf ${TMP_DIR}/${BUILDID}

## Clean up blueprints and compose's in composer-cli
clean-all: clean cleanup-temp-buildfolder
	composer-cli compose status | grep ${PROJECT_NAME} | awk '{print $$1}' | xargs -I {} composer-cli compose delete {}
	composer-cli blueprints delete ${PROJECT_NAME}


## This help screen
help:
	@printf "Available targets:\n"
	@awk '/^[a-zA-Z\-_0-9%:\\]+/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = $$1; \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			gsub("\\\\", "", helpCommand); \
			gsub(":+$$", "", helpCommand); \
			printf "  \x1b[32;01m%-35s\x1b[0m %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort -u
	@printf "\nSuggestion:\n  make showconfig\n  sudo PROJECT_NAME=example make create\n  sudo PROJECT_NAME=example make update\n"
