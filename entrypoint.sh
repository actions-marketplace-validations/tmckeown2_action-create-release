#!/bin/sh
set -eu

# Check for required parameters
if [ -z "${INPUT_TAG}" ]; then
  echo "[sage-release-action] No 'tag' was supplied! Please supply a tag."
fi
if [ -z "${INPUT_JIRA_TICKET_PREFIX}" ]; then
  echo "[sage-release-action] No 'jira_ticket_prefix' was supplied! Please supply a Jira ticket prefix."
fi
if [ -z "${INPUT_COMPONENT}" ]; then
  echo "[sage-release-action] No 'component' was supplied! Please supply a component name."
fi

# Set up variables
TAG="${INPUT_TAG}"
JIRA_TICKET_PREFIX="${INPUT_JIRA_TICKET_PREFIX}"
COMPONENT="${INPUT_COMPONENT}"
PREVIOUS_TAG="${INPUT_PREVIOUS_TAG:-'TEST PREVIOUS TAG'}" # TODO: Default to using `$(git describe --abbrev=0 --tags || git rev-list --max-parents=0 HEAD)`
COMMIT_SHA="${INPUT_COMMIT_SHA:-'HEAD'}"

git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

## DEBUG echo vars
echo "TAG = ${TAG}"
echo "JIRA_TICKET_PREFIX = ${JIRA_TICKET_PREFIX}"
echo "COMPONENT = ${COMPONENT}"
echo "PREVIOUS_TAG = ${PREVIOUS_TAG}"
echo "COMMIT_SHA = ${COMMIT_SHA}"

# Create tag
echo "[sage-release-action] Create tag '${TAG}'."

## Check tag doesn't already exist
if [[ "$(git tag -l)" == *"${TAG}"* ]]; then
  echo "[sage-release-action] Tag '${TAG}' already exists"
  exit 1
fi
## Create lightweight tag
### git tag "${TAG}" "${COMMIT_SHA}"

# Create github release
echo "[sage-release-action] Create GitHub release."
echo "TODO"

# Create jira release
echo "[sage-release-action] Create Jira release."
echo "TODO"