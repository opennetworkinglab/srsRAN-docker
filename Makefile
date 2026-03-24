# SPDX-FileCopyrightText: 2021 Open Networking Foundation <info@opennetworking.org>
# Copyright 2019 free5GC.org
#
# SPDX-License-Identifier: Apache-2.0
#
#

PROJECT_NAME             := srsran
DOCKER_VERSION           ?= $(shell cat ./VERSION)

## Docker related
DOCKER_REGISTRY          ?=
DOCKER_REPOSITORY        ?=
DOCKER_TAG               ?= ${DOCKER_VERSION}
DOCKER_BUILDKIT          ?= 1
DOCKER_BUILD_ARGS        ?=

## Docker labels with error handling
DOCKER_LABEL_VCS_URL     ?= $(shell git remote get-url origin 2>/dev/null || echo "unknown")
DOCKER_LABEL_VCS_REF     ?= $(shell \
	echo "$${GIT_COMMIT:-$${GITHUB_SHA:-$${CI_COMMIT_SHA:-$(shell \
		if git rev-parse --git-dir > /dev/null 2>&1; then \
			git rev-parse HEAD 2>/dev/null; \
		else \
			echo "unknown"; \
		fi \
	)}}}")
DOCKER_LABEL_BUILD_DATE  ?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")

## Upstream source refs (must match Dockerfile ARG defaults)
SRSRAN_GNB_REF           ?= release_25_10
SRSRAN_UE_REF            ?= release_23_11
OCUDU_REF                ?= release_26_04_rc1

## Resolve upstream refs to commit SHAs via git ls-remote
SRSRAN_GNB_COMMIT        ?= $(shell git ls-remote https://github.com/srsran/srsRAN_Project.git refs/tags/$(SRSRAN_GNB_REF)^{} refs/tags/$(SRSRAN_GNB_REF) refs/heads/$(SRSRAN_GNB_REF) 2>/dev/null | cut -f1 | head -n1 || echo "unknown")
SRSRAN_UE_COMMIT         ?= $(shell git ls-remote https://github.com/srsran/srsRAN_4G.git refs/tags/$(SRSRAN_UE_REF)^{} refs/tags/$(SRSRAN_UE_REF) refs/heads/$(SRSRAN_UE_REF) 2>/dev/null | cut -f1 | head -n1 || echo "unknown")
OCUDU_COMMIT             ?= $(shell git ls-remote https://gitlab.com/ocudu/ocudu.git refs/tags/$(OCUDU_REF)^{} refs/tags/$(OCUDU_REF) refs/heads/$(OCUDU_REF) 2>/dev/null | cut -f1 | head -n1 || echo "unknown")

DOCKER_TARGETS           ?= gnb ue ocudu

.PHONY: docker-build docker-push

.DEFAULT_GOAL: docker-build

docker-build:
	for target in $(DOCKER_TARGETS); do \
		case $$target in \
			gnb)    _UPSTREAM_COMMIT="$(SRSRAN_GNB_COMMIT)" ;; \
			ue)     _UPSTREAM_COMMIT="$(SRSRAN_UE_COMMIT)" ;; \
			ocudu)  _UPSTREAM_COMMIT="$(OCUDU_COMMIT)" ;; \
			*)      _UPSTREAM_COMMIT="unknown" ;; \
		esac; \
		case $$target in \
			gnb)    _TARGET_BUILD_ARGS="--build-arg SRSRAN_REF=$(SRSRAN_GNB_REF)" ;; \
			ue)     _TARGET_BUILD_ARGS="--build-arg SRSRAN_REF=$(SRSRAN_UE_REF)" ;; \
			ocudu)  _TARGET_BUILD_ARGS="--build-arg OCUDU_REF=$(OCUDU_REF)" ;; \
			*)      _TARGET_BUILD_ARGS="" ;; \
		esac; \
		case $$target in \
			ocudu)  _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}$$target:${DOCKER_TAG}" ;; \
			*)      _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}${PROJECT_NAME}-$$target:${DOCKER_TAG}" ;; \
		esac; \
		DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build $(DOCKER_BUILD_ARGS) \
			--file Dockerfile-$$target \
			--target $$target \
			--tag $$_IMAGE_NAME \
			--build-arg VERSION="${DOCKER_VERSION}" \
			--build-arg VCS_URL="${DOCKER_LABEL_VCS_URL}" \
			--build-arg VCS_REF="${DOCKER_LABEL_VCS_REF}" \
			--build-arg BUILD_DATE="${DOCKER_LABEL_BUILD_DATE}" \
			--build-arg UPSTREAM_COMMIT="$$_UPSTREAM_COMMIT" \
			$$_TARGET_BUILD_ARGS \
			. \
			|| exit 1; \
	done

docker-push:
	for target in $(DOCKER_TARGETS); do \
		case $$target in \
			ocudu)  _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}$$target:${DOCKER_TAG}" ;; \
			*)      _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}${PROJECT_NAME}-$$target:${DOCKER_TAG}" ;; \
		esac; \
		docker push $$_IMAGE_NAME; \
	done
