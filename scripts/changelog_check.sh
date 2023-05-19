#!/bin/bash

# Simply check if diff in changelog exists.
git diff --exit-code --quiet origin/master... ./$1/CHANGELOG.md
if [ $? -ne 1 ]; then
  echo "Following files have been changed:"
  echo $(git diff --name-only origin/master... ./$1)
  echo ""
  echo "Please add a changelog entry in $1/CHANGELOG.md or add 'skip changelog' label to your PR if this change does not require an entry".
  exit 1
fi
