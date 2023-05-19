#!/bin/bash

# Simply check if diff in 'version' exists in the chart file.
git diff origin/master... ./$1/Chart.yaml | grep -q "+version";
if [ $? -ne 0 ]; then
  echo "Following files have been changed:"
  echo $(git diff --name-only origin/master... ./$1)
  echo ""
  echo "Chart version in $1/Chart.yaml needs to be updated."
  exit 1
fi
