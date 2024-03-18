SHELL=bash

ENVFILE ?= ../.env-${PROJECT_NAME}
ENVFILE_EXAMPLE ?= template/.env-example

RHEL_ISO_FILENAME ?= rhel-9.3-x86_64-boot.iso
CURRENT_DIR := $(shell pwd)
TEMPLATE_DIR := ${CURRENT_DIR}/templates
TMP_DIR ?= ${CURRENT_DIR}/tmp/${PROJECT_NAME}
BUILDID ?= ""

OSTREE_REPO_PATH ?= /mnt/redhat/ostree
OSTREE_REPO_URL ?= http://localhost/ostree/repo
OSTREE_BRANCH ?= DEV

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
ifneq (,$(wildcard ${ENVFILE}))
    include ${ENVFILE}
    export
endif


define newline # a literal \n


endef

.PHONY: clean create-temp-dir

default: help

## Show configuration variables
showconfig: p-SHELL p-PROJECT_NAME p-ENVFILE p-RHEL_ISO_FILENAME p-CURRENT_DIR p-TEMPLATE_DIR p-TMP_DIR p-BUILDID p-OSTREE_REPO_PATH p-OSTREE_REPO_URL p-OSTREE_BRANCH p-BLUEPRINT_FILENAME p-BLUEPRINT_TEMPLATE p-KICKSTART_FILENAME p-KICKSTART_SHORT_FILENAME p-KICKSTART_TEMPLATE p-HTTPD_PATH p-SSH_KEY_PATH p-SSH_USER p-ADMIN_SSH_KEY p-USER_SSH_KEY p-ADMIN_SSH_KEY_CONTENTS p-USER_SSH_KEY_CONTENTS p-PULL_SECRET_DIR p-PULL_SECRET_FILE p-PULL_SECRET 

p-%:
	@echo '$*=$(subst ','\'',$(subst $(newline),\n,$($*)))'

# make sure the unique tmp folder exists, run in .PHONY
create-temp-dir:
	mkdir -p ${TMP_DIR}

# Main target for creating new ostree repo
create: blueprint kickstart push-blueprint build-new-image create-temp-buildfolder extract-image create-repo deploy-kickstart
	echo BUILDID=${BUILDID}

# Main target for updating ostree repo from new template.
update: blueprint kickstart push-blueprint build-update-image create-temp-buildfolder extract-image update-repo cleanup-temp-buildfolder
	echo BUILDID=${BUILDID}

## Generate custom blueprint file ${BLUEPRINT_FILENAME}.toml
blueprint: create-temp-dir custom-blueprint

custom-blueprint: ${BLUEPRINT_TEMPLATE}

${PROJECT_NAME}.toml.tpl: ${PROJECT_NAME}.toml

${PROJECT_NAME}.toml:
ifeq ($(PROJECT_NAME),'')
	@echo "❗ERROR project name not detected. Ensure env vars are exported and make is prefixed with PROJECT_NAME=<myproject>."
	exit 1
endif
	cat ${TEMPLATE_DIR}/${BLUEPRINT_TEMPLATE} | envsubst > ${TMP_DIR}/${BLUEPRINT_FILENAME}

## Generate custom kickstart file ${KICKSTART_FILENAME}.toml
kickstart: create-temp-dir ${KICKSTART_TEMPLATE}

${PROJECT_NAME}.ks.tpl: ${PROJECT_NAME}.ks

${PROJECT_NAME}.ks:
ifeq ($(PROJECT_NAME),'')
	@echo "❗ERROR project name not detected. Ensure env vars are exported and make is prefixed with PROJECT_NAME=<myproject>."
	exit 1
endif
	cat ${TEMPLATE_DIR}/${KICKSTART_TEMPLATE} | envsubst > ${TMP_DIR}/${KICKSTART_FILENAME}

deploy-kickstart: kickstart
	cp ${TMP_DIR}/${KICKSTART_FILENAME} ${HTTPD_PATH}/${KICKSTART_SHORT_FILENAME}

push-blueprint:
	composer-cli blueprints push ${TMP_DIR}/${BLUEPRINT_FILENAME};

build-new-image: start-build wait-for-build

build-update-image: start-update-build wait-for-build

start-build:
	$(eval BUILDID=$(shell composer-cli compose start-ostree rhel9-microshift edge-commit | awk '{print $$2}'))
	@echo new BUILDID is ${BUILDID}

start-update-build:
	$(eval BUILDID=$(shell composer-cli compose start-ostree rhel9-microshift edge-commit --url https://httpd.revoweb.com/redhat/ostree/repo --ref rhel/9/x86_64/edge | awk '{print $$2}'))
	@echo update BUILDID is ${BUILDID}

wait-for-build:
	@echo wait for build ${BUILDID} to stop RUNNING
	set -e; \
	while [[ "$$(composer-cli compose status | grep ${BUILDID} | awk '{print $$2}')" == 'RUNNING' ]]; do echo RUNNING $$(date); sleep 30; done;
	@echo done waiting;

create-temp-buildfolder:
	@echo BUILDID=${BUILDID}
	#rm -rf ${TMP_DIR}/${BUILDID}
	mkdir -p ${TMP_DIR}/${BUILDID}

extract-image: create-temp-buildfolder
	composer-cli compose image ${BUILDID} --filename ${TMP_DIR}/${BUILDID}/
	tar -xf ${TMP_DIR}/${BUILDID}/${BUILDID}-commit.tar -C ${TMP_DIR}/${BUILDID}/

create-repo: 
	rm -rf ${OSTREE_REPO_PATH}/repo
	tar -xf ${TMP_DIR}/${BUILDID}/${BUILDID}-commit.tar -C ${OSTREE_REPO_PATH}/


update-repo: 
	ostree --repo=${OSTREE_REPO_PATH}/repo pull-local ${TMP_DIR}/${BUILDID}/repo

cleanup-temp-buildfolder:
	rm -rf ${TMP_DIR}/${BUILDID}


generate-password:
	openssl passwd -6

## Clean up a cluster install dir
clean:
	rm -rf \
		${CURRENT_DIR}/tmp/${PROJECT_NAME}

## Clean up blueprints and compose
clean-all: clean
	composer-cli compose status | grep ${PROJECT_NAME} | awk '{print $$1}' | xargs -I {} composer-cli compose delete {}
	composer-cli blueprints delete ${PROJECT_NAME}


## This help screen
help:
	@printf "Available targets:\n"
	@awk '/^[a-zA-Z\-\_0-9%:\\]+/ { \
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
