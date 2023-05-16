#!/bin/bash

# Simply check if diff in 'version' exists in the chart file.
git diff $1 | grep -q "+version";
if [ $? -ne 0 ]; then
  echo "Chart version in $1 needs to be updated."
  exit 1
fi
