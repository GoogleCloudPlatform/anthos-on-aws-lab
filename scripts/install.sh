#!/bin/bash
#
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -u
set -e

function install_terraform() {
  local TARGET="terraform"
  local RELEASE="0.13.5"
  local OS="linux"
  local SHA="f7b7a7b1bfbf5d78151cfe3d1d463140b5fd6a354e71a7de2b5644e652ca5147"
  local FILENAME="${TARGET}_${RELEASE}_${OS}_amd64.zip"
  local URI="https://releases.hashicorp.com/terraform/${RELEASE}/${FILENAME}"

  echo "Downloading and installing ${TARGET} release ${RELEASE} for ${OS}..."

  wget -O ${FILENAME} ${URI}

  SHASUM=$(cut -d ' ' -f 1 <<<$(sha256sum "$FILENAME"))
  if [ ${SHA} != ${SHASUM} ]; then
    echo "Signature ${SHASUM} of file download ${FILENAME} does not match expected value ${SHA}."
    exit 1
  fi

  unzip ${FILENAME}
  chmod +x ${TARGET}
  mv ${TARGET} ${BIN_DIR}
  ${TARGET} version
  echo "SUCCESS: ${TARGET} has been installed."
}

install_aws_cli() {
  local TARGET="aws"

  echo "Installing ${TARGET} for Linux..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install --install-dir ${BIN_DIR} --bin-dir ${BIN_DIR}

  ${TARGET} --version
  echo "SUCCESS: $TARGET has been installed."
}

install_anthos_gke() {
  local TARGET="anthos-gke"
  local RELEASE="aws-1.6.0-gke.3"

  gsutil cp gs://gke-multi-cloud-release/aws/${RELEASE}/bin/linux/amd64/${TARGET} .
  chmod 755 ${TARGET}
  mv ${TARGET} ${BIN_DIR}
  ${TARGET} version
  echo "SUCCESS: ${TARGET} has been installed."
}

rm -rf ${TMP_DIR}/*
rm -rf ${BIN_DIR}/*

cd ${TMP_DIR}
install_terraform
install_aws_cli
install_anthos_gke
