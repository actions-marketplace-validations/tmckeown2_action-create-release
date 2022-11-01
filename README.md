# GitHub Action: Create New Release

GitHub action for a release pipeline. Creates a new tag and pushes it to the remote, creates a new GitHub release, and triggers a Jira release using webhooks.

## Inputs

### `tag`
**Required**. Tag to create and use for the release.

### `previous_tag`
**Optional**. Tag to use as the previous. Defaults to latest tag or first commit if no tags exist

### `commit_sha`
**Optional**. Commit hash to tag. Defaults to HEAD commit

### `component`
**Required**. Component name for the release

### `jira_ticket_prefix`
**Required**. Prefix for the Jira tickets

### `jira_create_version_webhook`
**Required**. Webhook URL for the 'Create Version' automation within Jira project

### `jira_add_issues_webhook`
**Required**. Webhook URL for the 'Add Issues' automation within Jira project

## Example usage
```yml
name: Create release
on:
  workflow_dispatch:
    tag: 
      description: "Tag to create and use for the release"
      required: true
    previous_tag:
      description: "Tag to use as the previous"
      required: false
    commit_sha:
      description: "Commit hash to tag"
      required: false
jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
          token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
      - uses: tmckeown2/action-create-release@v1
        with:
          tag: "${{ github.event.inputs.tag }}"
          previous_tag: "${{ github.event.inputs.previous_tag }}"
          commit_sha: "${{ github.event.inputs.commit_sha }}"
          component: "TEST_COMPONENT"
          jira_ticket_prefix: "TICKET"
          jira_create_version_webhook: "<URL>"
          jira_add_issues_webhook: "<URL>"
```
