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
OCUDU_REF                ?= release_26_04
UERANSIM_REF             ?= v3.2.7

SRSRAN_GNB_REPO          ?= https://github.com/srsran/srsRAN_Project.git
SRSRAN_UE_REPO           ?= https://github.com/srsran/srsRAN_4G.git
OCUDU_REPO               ?= https://gitlab.com/ocudu/ocudu.git
UERANSIM_REPO            ?= https://github.com/aligungr/UERANSIM.git

DOCKER_TARGETS           ?= gnb ue ocudu ueransim

.PHONY: docker-build docker-push

.DEFAULT_GOAL: docker-build

docker-build:
	for target in $(DOCKER_TARGETS); do \
		case $$target in \
			gnb)    _UPSTREAM_REPO="$(SRSRAN_GNB_REPO)"; _UPSTREAM_REF="$(SRSRAN_GNB_REF)" ;; \
			ue)     _UPSTREAM_REPO="$(SRSRAN_UE_REPO)"; _UPSTREAM_REF="$(SRSRAN_UE_REF)" ;; \
			ocudu)  _UPSTREAM_REPO="$(OCUDU_REPO)"; _UPSTREAM_REF="$(OCUDU_REF)" ;; \
			ueransim) _UPSTREAM_REPO="$(UERANSIM_REPO)"; _UPSTREAM_REF="$(UERANSIM_REF)" ;; \
			*)      _UPSTREAM_REPO=""; _UPSTREAM_REF="" ;; \
		esac; \
		if [ -n "$$_UPSTREAM_REPO" ]; then \
			_UPSTREAM_COMMIT=$$(git ls-remote "$$_UPSTREAM_REPO" "refs/tags/$$_UPSTREAM_REF^{}" "refs/tags/$$_UPSTREAM_REF" "refs/heads/$$_UPSTREAM_REF" 2>/dev/null | awk 'NR == 1 { print $$1; found = 1 } END { if (!found) print "unknown" }'); \
		else \
			_UPSTREAM_COMMIT="unknown"; \
		fi; \
		case $$target in \
			gnb)    _TARGET_BUILD_ARGS="--build-arg SRSRAN_REF=$(SRSRAN_GNB_REF)" ;; \
			ue)     _TARGET_BUILD_ARGS="--build-arg SRSRAN_REF=$(SRSRAN_UE_REF)" ;; \
			ocudu)  _TARGET_BUILD_ARGS="--build-arg OCUDU_REF=$(OCUDU_REF)" ;; \
			ueransim) _TARGET_BUILD_ARGS="--build-arg UERANSIM_REF=$(UERANSIM_REF)" ;; \
			*)      _TARGET_BUILD_ARGS="" ;; \
		esac; \
		case $$target in \
			ocudu|ueransim) _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}$$target:${DOCKER_TAG}" ;; \
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
			ocudu|ueransim) _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}$$target:${DOCKER_TAG}" ;; \
			*)      _IMAGE_NAME="${DOCKER_REGISTRY}${DOCKER_REPOSITORY}${PROJECT_NAME}-$$target:${DOCKER_TAG}" ;; \
		esac; \
		docker push $$_IMAGE_NAME; \
	done
