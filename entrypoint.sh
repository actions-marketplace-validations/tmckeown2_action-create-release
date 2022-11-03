#!/bin/sh
set -eu

# Apply hotfix for 'fatal: unsafe repository' error
echo "[action-create-release] Applying hotfix for 'fatal: unsafe repository' error"
git config --global --add safe.directory "${GITHUB_WORKSPACE}"
cd "${GITHUB_WORKSPACE}" || exit

# Check for required parameters
echo "[action-create-release] Checking for required parameters"
MISSING_PARAMS="false"
if [ -z "${INPUT_TAG}" ]; then
  echo "[action-create-release] No 'tag' was supplied! Please supply a tag."
  echo "ERROR: No 'tag' was supplied! Please supply a tag." >> ${GITHUB_STEP_SUMMARY}
  MISSING_PARAMS="true"
fi
if [ -z "${INPUT_COMPONENT}" ]; then
  echo "[action-create-release] No 'component' was supplied! Please supply a component name."
  echo "ERROR: No 'component' was supplied! Please supply a component name." >> ${GITHUB_STEP_SUMMARY}
  MISSING_PARAMS="true"
fi
if [ -z "${INPUT_JIRA_TICKET_PREFIX}" ]; then
  echo "[action-create-release] No 'jira_ticket_prefix' was supplied! Please supply a Jira ticket prefix."
  echo "ERROR: No 'jira_ticket_prefix' was supplied! Please supply a Jira ticket prefix." >> ${GITHUB_STEP_SUMMARY}
  MISSING_PARAMS="true"
fi
if [ -z "${INPUT_JIRA_CREATE_VERSION_WEBHOOK}" ]; then
  echo "[action-create-release] No 'jira_create_version_webhook' was supplied! Please supply a Jira webhook URL for 'Create Version' automation."
  echo "ERROR: No 'jira_create_version_webhook' was supplied! Please supply a Jira webhook URL for 'Create Version' automation." >> ${GITHUB_STEP_SUMMARY}
  MISSING_PARAMS="true"
fi
if [ -z "${INPUT_JIRA_ADD_ISSUES_WEBHOOK}" ]; then
  echo "[action-create-release] No 'jira_add_issues_webhook' was supplied! Please supply a Jira webhook URL for 'Add Issues' automation."
  echo "ERROR: No 'jira_add_issues_webhook' was supplied! Please supply a Jira webhook URL for 'Add Issues' automation." >> ${GITHUB_STEP_SUMMARY}
  MISSING_PARAMS="true"
fi
if [ "${MISSING_PARAMS}" == "true" ]; then
  echo "[action-create-release] ERROR: Missing parameters. Exiting"
  echo "ERROR: Missing parameters" >> ${GITHUB_STEP_SUMMARY}
  exit 1
fi

# Set up variables
echo "[action-create-release] Setting up variables"
TAG="${INPUT_TAG}"
PREVIOUS_TAG="${INPUT_PREVIOUS_TAG:-$(git describe --abbrev=0 --tags || git rev-list --max-parents=0 HEAD)}"
COMMIT_SHA="${INPUT_COMMIT_SHA:-$(git rev-parse HEAD)}"
COMPONENT="${INPUT_COMPONENT}"
JIRA_TICKET_PREFIX="${INPUT_JIRA_TICKET_PREFIX}"
JIRA_CREATE_VERSION_WEBHOOK="${INPUT_JIRA_CREATE_VERSION_WEBHOOK}"
JIRA_ADD_ISSUES_WEBHOOK="${INPUT_JIRA_ADD_ISSUES_WEBHOOK}"

echo "# ENV VARS" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}
printenv >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}

echo "[action-create-release] Getting merges"
MERGES="$(git log --merges --oneline ${PREVIOUS_TAG}..${COMMIT_SHA})"
echo "[action-create-release] Building GitHub release issues list"
GITHUB_RELEASE_RELATED_ISSUES="$(echo "${MERGES}" \
  | grep 'Merge pull request #' \
  | awk '{print $7}' \
  | sed s:Sage/:: \
  | sort \
  | uniq \
  | awk '{printf "- [%1$s](https://jira.sage.com/browse/%1$s)\n", $0}' )"
echo "[action-create-release] Building Jira release issues list"
JIRA_RELEASE_RELATED_ISSUES="$(echo "${MERGES}" \
  | grep 'Merge pull request #' \
  | awk '{print $7}' \
  | sed s:Sage/:: \
  | sort \
  | uniq \
  | sed "/^${JIRA_TICKET_PREFIX}-[0-9]*$/!d" \
  | paste -sd ,)"

echo "# Vars" >> ${GITHUB_STEP_SUMMARY}
echo "TAG='${TAG}'" >> ${GITHUB_STEP_SUMMARY}
echo "PREVIOUS_TAG='${PREVIOUS_TAG}'" >> ${GITHUB_STEP_SUMMARY}
echo "COMMIT_SHA='${COMMIT_SHA}'" >> ${GITHUB_STEP_SUMMARY}
echo "COMPONENT='${COMPONENT}'" >> ${GITHUB_STEP_SUMMARY}
echo "JIRA_TICKET_PREFIX='${JIRA_TICKET_PREFIX}'" >> ${GITHUB_STEP_SUMMARY}

echo "# Merges log" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}
echo "${MERGES}" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}

echo "# GitHub release related issues" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}
echo "${GITHUB_RELEASE_RELATED_ISSUES}" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}

echo "# Jira release related issues" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}
echo "${JIRA_RELEASE_RELATED_ISSUES}" >> ${GITHUB_STEP_SUMMARY}
echo "\`\`\`" >> ${GITHUB_STEP_SUMMARY}

echo "[action-create-release] Setting git config"
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

# Create tag
echo "[action-create-release] Create tag '${TAG}'."

## Check tag doesn't already exist
echo "[action-create-release] Checking that the tag doesn't already exist"
if [[ "$(git tag -l)" == *"${TAG}"* ]]; then
  echo "[action-create-release] ERROR: Tag '${TAG}' already exists"
  echo "ERROR: Tag '${TAG}' already exists" >> ${GITHUB_STEP_SUMMARY}
  exit 1
fi
## Check there have been changes since latest tag
echo "[action-create-release] Checking for changes since previous tag"
if [ -z "${MERGES}" ]; then
  echo "[action-create-release] No changes to release"
  echo "No changes to release" >> ${GITHUB_STEP_SUMMARY}
  exit 1
fi
## Create lightweight tag
echo "[action-create-release] Creating the lightweight tag"
git tag "${TAG}" "${COMMIT_SHA}"
if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
  git remote set-url origin "https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi
echo "[action-create-release] Pushing the new tag"
git push origin "${TAG}"

# Create github release
echo "[action-create-release] Create GitHub release."

## Call GitHub API to create a release
echo "[action-create-release] Building GitHub json request body"
GITHUB_API_DATA=$(jq -Rnc \
  --arg tag_name "${TAG}" \
  --arg body "${GITHUB_RELEASE_RELATED_ISSUES}" \
  '{ "tag_name": $tag_name, "prerelease": true, "generate_release_notes": true, "body": $body }')
echo "[action-create-release] Calling GitHub API to create a release"
echo "# GitHub request" >> ${GITHUB_STEP_SUMMARY}
echo "${GITHUB_API_DATA}" >> ${GITHUB_STEP_SUMMARY}
curl \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
  https://api.github.com/repos/${GITHUB_REPOSITORY}/releases \
  -d "${GITHUB_API_DATA}"

# Create jira release
echo "[action-create-release] Create Jira release."

## Build the request data
echo "[action-create-release] Cutting out the release date"
RELEASE_DATE=$(echo "${TAG}" | cut -d '.' -f 1)
echo "[action-create-release] Splitting Jira issues list into a json array"
ISSUES=$(jq -Rnc --arg issues "${JIRA_RELEASE_RELATED_ISSUES}" '$issues | split(",")')
echo "[action-create-release] Building Jira json request body"
JIRA_VERSION_DATA=$(jq -Rnc \
  --arg component "${COMPONENT}" \
  --arg tag "${TAG}" \
  --arg releaseDate "${RELEASE_DATE}" \
  --argjson issues "${ISSUES}" \
  '{ "component": $component, "tag": $tag, "releaseDate": $releaseDate, "issues": $issues }')

echo "# Jira request" >> ${GITHUB_STEP_SUMMARY}
echo "${JIRA_VERSION_DATA}" >> ${GITHUB_STEP_SUMMARY}

## Create the Jira version
echo "[action-create-release] Calling Jira webhook for 'Create Version' automation"
curl \
  -X POST \
  -H 'Content-type: application/json' \
  ${JIRA_CREATE_VERSION_WEBHOOK} \
  -d "${JIRA_VERSION_DATA}"

## Add issues to Jira version
echo "[action-create-release] Calling Jira webhook for 'Add Issues' automation"
curl \
  -X POST \
  -H 'Content-type: application/json' \
  ${JIRA_ADD_ISSUES_WEBHOOK} \
  -d "${JIRA_VERSION_DATA}"