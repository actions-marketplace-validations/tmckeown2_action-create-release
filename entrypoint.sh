#!/bin/sh
set -eu

# Apply hotfix for 'fatal: unsafe repository' error
git config --global --add safe.directory "${GITHUB_WORKSPACE}"
cd "${GITHUB_WORKSPACE}" || exit

# Check for required parameters
if [ -z "${INPUT_TAG}" ]; then
  echo "[action-create-release] No 'tag' was supplied! Please supply a tag."
fi
if [ -z "${INPUT_COMPONENT}" ]; then
  echo "[action-create-release] No 'component' was supplied! Please supply a component name."
fi
if [ -z "${INPUT_JIRA_TICKET_PREFIX}" ]; then
  echo "[action-create-release] No 'jira_ticket_prefix' was supplied! Please supply a Jira ticket prefix."
fi
if [ -z "${INPUT_JIRA_CREATE_VERSION_WEBHOOK}" ]; then
  echo "[action-create-release] No 'jira_create_version_webhook' was supplied! Please supply a Jira webhook URL for 'Create Version' automation."
fi
if [ -z "${INPUT_JIRA_ADD_ISSUES_WEBHOOK}" ]; then
  echo "[action-create-release] No 'jira_add_issues_webhook' was supplied! Please supply a Jira webhook URL for 'Add Issues' automation."
fi

# Set up variables
TAG="${INPUT_TAG}"
PREVIOUS_TAG="${INPUT_PREVIOUS_TAG:-$(git describe --abbrev=0 --tags || git rev-list --max-parents=0 HEAD)}"
COMMIT_SHA="${INPUT_COMMIT_SHA:-$(git rev-parse HEAD)}"
COMPONENT="${INPUT_COMPONENT}"
JIRA_TICKET_PREFIX="${INPUT_JIRA_TICKET_PREFIX}"
JIRA_CREATE_VERSION_WEBHOOK="${INPUT_JIRA_CREATE_VERSION_WEBHOOK}"
JIRA_ADD_ISSUES_WEBHOOK="${INPUT_JIRA_ADD_ISSUES_WEBHOOK}"

MERGES="$(git log --merges --oneline ${PREVIOUS_TAG}..${COMMIT_SHA})"
GITHUB_RELEASE_RELATED_ISSUES="$(git log --merges --oneline ${PREVIOUS_TAG}..${COMMIT_SHA} \
  | grep 'Merge pull request #' \
  | awk '{print $7}' \
  | sed s:Sage/:: \
  | sort \
  | uniq \
  | awk '{printf "- [%1$s](https://jira.sage.com/browse/%1$s)\\n", $0}' )"
JIRA_RELEASE_RELATED_ISSUES="$(git log --merges --oneline ${{ needs.createTag.outputs.latestTag }}..${{ needs.createTag.outputs.tagCommit }} \
  | grep 'Merge pull request #' \
  | awk '{print $7}' \
  | sed s:Sage/:: \
  | sort \
  | uniq \
  | sed "/^${TICKET_PREFIX}-[0-9]*$/!d" \
  | paste -sd ,)"

git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

# Create tag
echo "[action-create-release] Create tag '${TAG}'."

## Check tag doesn't already exist
if [[ "$(git tag -l)" == *"${TAG}"* ]]; then
  echo "[action-create-release] Tag '${TAG}' already exists"
  exit 1
fi
## Check there have been changes since latest tag
if [ -z "${MERGES}" ]; then
  echo "[action-create-release] No changes to release"
  exit 1
fi
## Create lightweight tag
git tag "${TAG}" "${COMMIT_SHA}"
if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
  git remote set-url origin "https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi
git push origin "${TAG}"


# Create github release
echo "[action-create-release] Create GitHub release."

## Call GitHub API to create a release
GITHUB_API_DATA=$(jq -Rnc \
  --arg tag_name "${TAG}" \
  --arg prerelease "true" \
  --arg generate_release_notes "true" \
  --arg body "${GITHUB_RELEASE_RELATED_ISSUES}" \
  '{ "tag_name": $tag_name, "prerelease": $prerelease, "generate_release_notes": $generate_release_notes, "body": $body }')
curl \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
  https://api.github.com/repos/${GITHUB_REPOSITORY}/releases \
  -d "${GITHUB_API_DATA}"

# Create jira release
echo "[action-create-release] Create Jira release."

## Build the request data
RELEASE_DATE=$(echo "${TAG}" | cut -d '.' -f 1)
ISSUES=$(jq -Rnc --arg issues "${JIRA_RELEASE_RELATED_ISSUES}" '$issues | split(",")')
JIRA_VERSION_DATA=$(jq -Rnc \
  --arg component "${COMPONENT}" \
  --arg tag "${TAG}" \
  --arg releaseDate "${RELEASE_DATE}" \
  --argjson issues "${ISSUES}" \
  '{ "component": $component, "tag": $tag, "releaseDate": $releaseDate, "issues": $issues }')

## Create the Jira version
curl \
  -X POST \
  -H 'Content-type: application/json' \
  ${JIRA_CREATE_VERSION_WEBHOOK}
  -d "${JIRA_VERSION_DATA}"

## Add issues to Jira version
curl \
  -X POST \
  -H 'Content-type: application/json' \
  ${JIRA_ADD_ISSUES_WEBHOOK}
  -d "${JIRA_VERSION_DATA}"