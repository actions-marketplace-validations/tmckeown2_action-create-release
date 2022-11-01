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
PREVIOUS_TAG="${INPUT_PREVIOUS_TAG:-'TEST PREVIOUS TAG'}" # TODO: Default to using `$(git describe --abbrev=0 --tags || git rev-list --max-parents=0 HEAD)`
COMMIT_SHA="${INPUT_COMMIT_SHA:-'HEAD'}"
COMPONENT="${INPUT_COMPONENT}"
JIRA_TICKET_PREFIX="${INPUT_JIRA_TICKET_PREFIX}"
JIRA_CREATE_VERSION_WEBHOOK="${INPUT_JIRA_CREATE_VERSION_WEBHOOK}"
JIRA_ADD_ISSUES_WEBHOOK="${INPUT_JIRA_ADD_ISSUES_WEBHOOK}"

git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

## DEBUG echo vars
echo "TAG = ${TAG}"
echo "PREVIOUS_TAG = ${PREVIOUS_TAG}"
echo "COMMIT_SHA = ${COMMIT_SHA}"
echo "COMPONENT = ${COMPONENT}"
echo "JIRA_TICKET_PREFIX = ${JIRA_TICKET_PREFIX}"
echo "JIRA_CREATE_VERSION_WEBHOOK = ${JIRA_CREATE_VERSION_WEBHOOK}"
echo "JIRA_ADD_ISSUES_WEBHOOK = ${JIRA_ADD_ISSUES_WEBHOOK}"

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