#!/bin/bash

git diff $1 | grep -q "+version";
if [ $? -ne 0 ]; then
  echo "Chart version in $1 needs to be updated."
  exit 1
fi