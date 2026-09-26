# Copyright 2022 ETH Zurich and University of Bologna
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
# Author: Manuel Eggimann

# This utility makefile sets up a virtual environment in a newly create .venv
# subdirectory of this folder and install various commonly used python tools
# within it.

ifndef utils_mk
utils_mk=1

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))
export PULPISSIMO_UTILS=$(mkfile_dir)/bin

VENVDIR?=$(mkfile_path)/.venv
REQUIREMENTS_TXT?=$(wildcard requirements.txt)
include $(mkfile_dir)/venv.mk

$(PULPISSIMO_UTILS)/padrick:
ifeq (,$(widlcard bin/padrick))
	mkdir -p $(PULPISSIMO_UTILS)
	cd $(PULPISSIMO_UTILS) && curl https://api.github.com/repos/pulp-platform/padrick/releases/tags/v0.3.6 \
    | grep "browser_download_url.*Padrick-x86_64.AppImage" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | wget -qi -
	mv $(PULPISSIMO_UTILS)/Padrick-x86_64.AppImage $(PULPISSIMO_UTILS)/padrick
	chmod a+x $(PULPISSIMO_UTILS)/padrick
endif

# Bender version to install. Do not change without regenerating Bender.lock
# (`make bender BENDER_VERSION=<version> && ./utils/bin/bender checkout`).
BENDER_VERSION ?= 0.28.0

# The pulp-platform installer script detects the platform from /etc/os-release
# and silently falls back to the latest legacy release (0.31.0) whenever the
# pinned version has no asset for the detected platform. On EL8 derivatives
# whose exact point release has no asset (e.g. almalinux8.10), this overrides
# the pinned version. Instead of relying on the installer, resolve the
# platform here and prefer an EL8-compatible asset for the pinned version,
# falling back to the installer only when no direct asset can be found.
# Manual override: BENDER_PLATFORM=x86_64-linux-gnu-almalinux8.9
BENDER_PLATFORM ?=

.PHONY: bender
## Download the pinned Bender binary into utils/bin (forced reinstall)
## @param BENDER_VERSION=0.28.0 Bender release to install
## @param BENDER_PLATFORM= Force a specific release platform tag (e.g. x86_64-linux-gnu-almalinux8.9)
bender:
	@rm -f $(PULPISSIMO_UTILS)/bender
	@$(MAKE) $(PULPISSIMO_UTILS)/bender

$(PULPISSIMO_UTILS)/bender:
	@test -n "$(BENDER_VERSION)" || { printf 'BENDER_VERSION is empty.\n' >&2; exit 1; }
	@mkdir -p $(PULPISSIMO_UTILS)
	@if test -n "$(BENDER_PLATFORM)"; then \
	  platform="$(BENDER_PLATFORM)"; \
	else \
	  os_id=$$(sed -n -e 's/^ID=//p' /etc/os-release | tr -d '"'); \
	  os_version=$$(sed -n -e 's/^VERSION_ID=//p' /etc/os-release | tr -d '"'); \
	  os_major=$$(echo "$$os_version" | cut -d. -f1); \
	  platform="x86_64-linux-gnu-$${os_id}$${os_version}"; \
	  case "$$platform" in \
	    x86_64-linux-gnu-almalinux*|x86_64-linux-gnu-rhel*|x86_64-linux-gnu-rocky*) \
	      for minor in 9 8 7 6; do \
	        candidate="x86_64-linux-gnu-$${os_id}$${os_major}.$$minor"; \
	        url=$$(curl -s https://api.github.com/repos/pulp-platform/bender/releases/tags/v$(BENDER_VERSION) \
	          | grep -Eo "    \"browser_download_url\": \".*?bender-.*-$$candidate\.tar\.gz\"" \
	          | grep -Eo "http.*?bender-.*-$$candidate\.tar\.gz" | head -n1); \
	        if test -n "$$url"; then platform="$$candidate"; break; fi; \
	      done; \
	      ;; \
	  esac; \
	fi; \
	release_json=$$(curl -s https://api.github.com/repos/pulp-platform/bender/releases/tags/v$(BENDER_VERSION)); \
	url=$$(printf '%s' "$$release_json" \
	  | grep -Eo "    \"browser_download_url\": \".*?bender-.*-$$platform\.tar\.gz\"" \
	  | grep -Eo "http.*?bender-.*-$$platform\.tar\.gz" | head -n1); \
	if test -z "$$url"; then \
	  case "$$platform" in \
	    x86_64-linux-gnu-*) \
	      url=$$(printf '%s' "$$release_json" \
	        | grep -Eo "    \"browser_download_url\": \".*?bender-.*-x86_64-linux-gnu\.tar\.gz\"" \
	        | grep -Eo "http.*?bender-.*-x86_64-linux-gnu\.tar\.gz" | head -n1); \
	      ;; \
	  esac; \
	fi; \
	if test -z "$$url"; then \
	  printf 'No bender %s asset for platform %s; falling back to the upstream installer.\n' \
	    "$(BENDER_VERSION)" "$$platform" >&2; \
	  cd $(PULPISSIMO_UTILS) && curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init \
	    | bash -s -- $(BENDER_VERSION); \
	else \
	  printf 'Downloading %s\n' "$$url" >&2; \
	  curl --proto '=https' --tlsv1.2 -sSfL $$url | tar xz -C $(PULPISSIMO_UTILS) bender; \
	fi; \
	chmod a+x $(PULPISSIMO_UTILS)/bender; \
	$(PULPISSIMO_UTILS)/bender -V


export PULPISSIMO_UTILS=$(mkfile_dir)/bin
endif
