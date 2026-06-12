#!/bin/bash

# Simply check if diff in 'version' exists in the chart file.
if ! git diff origin/master... -- "./$1/Chart.yaml" | grep -q "+version"; then
  echo "Following files have been changed:"
  git diff --name-only origin/master... -- "./$1"
  echo ""
  echo "Chart version in $1/Chart.yaml needs to be updated."
  exit 1
fi
