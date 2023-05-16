# Contributing Guide

* [New Contributor Guide](#contributing-guide)
  * [Ways to Contribute](#ways-to-contribute)
  * [Find an Issue](#find-an-issue)
  * [Ask for Help](#ask-for-help)
  * [Pull Request Lifecycle](#pull-request-lifecycle)
  * [Development Environment Setup](#development-environment-setup)
  * [Sign Your Commits](#sign-your-commits)
  * [Pull Request Checklist](#pull-request-checklist)

Welcome! We are glad that you want to contribute to our project! 💖

As you get started, you are in the best position to give us feedback on areas of
our project that we need help with including:

* Problems found during setting up a new developer environment
* Gaps in our Quickstart Guide or documentation
* Bugs in our automation scripts

If anything doesn't make sense, or doesn't work when you run it, please open a
bug report and let us know!

## Ways to Contribute

We welcome many different types of contributions including:

* New features
* Builds, CI/CD
* Bug fixes
* Documentation
* Issue Triage
* Answering questions on Github issues
* Communications / Social Media / Blog Posts
* Release management

## Find an Issue

We have good first issues for new contributors and help wanted issues suitable
for any contributor. [good first issue](https://github.com/coralogix/telemetry-shippers/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) has extra information to
help you make your first contribution. [help wanted](https://github.com/coralogix/telemetry-shippers/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22) are issues
suitable for someone who isn't a core maintainer and is good to move onto after
your first pull request.

Once you see an issue that you'd like to work on, please post a comment saying
that you want to work on it. Something like "I want to work on this" is fine.

## Ask for Help

The best way to reach us with a question when contributing is to ask on the original github issue.

## Pull Request Lifecycle

- Open a PR; if it's not finished yet, please make it a draft first
- Reviewers will be automatically assigned based on code owners
- Reviewers will get to the PR as soon as possible, but usually within 2 days

## Development Environment Setup

You must have a Helm Chart CLI available in your environment to install the charts on this repository.

If you don't have Helm installed yet, please check the official Helm documentation [here](https://helm.sh/docs/helm/helm_install/).

## Sign Your Commits

### CLA

We require that contributors have signed our Contributor License Agreement (CLA).

When a contributor submits their first Pull Request, the CLA Bot will step in with a friendly comment on the new pull request, kindly requesting them to sign the [Coralogix's CLA](https://cla-assistant.io/coralogix/telemetry-shippers).

## Pull Request Checklist

When you submit your pull request, or you push new commits to it, our automated
systems will run some checks on your new code. We require that your pull request
passes these checks, but we also have more criteria than just that before we can
accept and merge it. We recommend that you check the following things locally
before you submit your code:

- CLA,
- passing CI
- resolved discussions
