#!/bin/bash

# --------------------------------------------
# Options that must be configured by app owner
# --------------------------------------------
APP_NAME="image-builder-crc"  # name of app-sre "application" folder this component lives in
COMPONENT_NAME="image-builder-pulp"  # name of app-sre "resourceTemplate" in deploy.yaml for this component
IMAGE="quay.io/cloudservices/pulp-ostree-ubi"

export IQE_PLUGINS="image-builder"  # name of the IQE plugin for this app.
export IQE_CJI_TIMEOUT="30m"  # This is the time to wait for smoke test to complete or fail
export IQE_MARKER_EXPRESSION="api" # run only api test
export IQE_ENV="ephemeral" # run only api test
export REF_ENV="insights-stage"

# Install bonfire repo/initialize
CICD_URL=https://raw.githubusercontent.com/RedHatInsights/bonfire/master/cicd
curl -s $CICD_URL/bootstrap.sh > .cicd_bootstrap.sh && source .cicd_bootstrap.sh

EXTRA_DEPLOY_ARGS="--set-parameter image-builder-pulp/IMAGE_TAG=${IMAGE_TAG} provisioning sources content-sources"

source $CICD_ROOT/build.sh
source $APP_ROOT/unit_test.sh
source $CICD_ROOT/deploy_ephemeral_env.sh
source $CICD_ROOT/cji_smoke_test.sh
source $CICD_ROOT/post_test_results.sh
