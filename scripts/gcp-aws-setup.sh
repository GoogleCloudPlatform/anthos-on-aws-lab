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

function configure_gcp_project() {
  echo "Enable project APIs..."
  gcloud services enable \
    anthos.googleapis.com \
    cloudresourcemanager.googleapis.com \
    gkehub.googleapis.com \
    gkeconnect.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com \
    serviceusage.googleapis.com \
    stackdriver.googleapis.com \
    storage-api.googleapis.com \
    storage-component.googleapis.com

  echo "Creating Service Accounts..."
  local SA=${PROJECT_ID}.iam.gserviceaccount.com
  if ! (gcloud iam service-accounts list | grep management-sa@$SA); then gcloud iam service-accounts create management-sa; fi
  if ! (gcloud iam service-accounts list | grep hub-sa@$SA); then gcloud iam service-accounts create hub-sa; fi
  if ! (gcloud iam service-accounts list | grep node-sa@$SA); then gcloud iam service-accounts create node-sa; fi

  cd ${SECRETS_DIR}
  echo "Creating SA keys..."
  gcloud iam service-accounts keys create management-key.json --iam-account management-sa@$SA
  gcloud iam service-accounts keys create hub-key.json --iam-account hub-sa@$SA
  gcloud iam service-accounts keys create node-key.json --iam-account node-sa@$SA

  echo "Setting up proper IAM role bindings..."
  gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:management-sa@${SA} --role roles/gkehub.admin
  gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:management-sa@${SA} --role roles/serviceusage.serviceUsageViewer
  gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:hub-sa@${SA} --role roles/gkehub.connect
  gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:node-sa@${SA} --role roles/storage.objectViewer

  echo "SUCCESS: GCP project ID ${PROJECT_ID} preparation has been completed."
}

configure_aws_creds() {
  echo "Configuring AWS credentials..."
  local TEMP=${AWS_PROFILE}
  unset AWS_PROFILE
  aws configure --profile ${TEMP}
  export AWS_PROFILE=${TEMP}
}

create_aws_keys() {
  echo "Setting up data encryption key for AWS..."
  local KEY_ID=$(aws kms create-key --output json | jq -r .KeyMetadata.KeyId)

  # Redirect to NULL because for some reason on Mac this asks for user input, but not on Linux
  aws kms create-alias \
    --alias-name=alias/${AWS_DATA_KEY} \
    --target-key-id=${KEY_ID} > /dev/null

  echo "Setting up app encryption key for AWS..."
  local KEY_ID=$(aws kms create-key --output json | jq -r .KeyMetadata.KeyId)

  aws kms create-alias \
    --alias-name=alias/${AWS_APP_KEY} \
    --target-key-id=${KEY_ID} > /dev/null
}

configure_aws_creds
create_aws_keys
