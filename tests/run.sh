#!/usr/bin/env bash
# Back me up tests. Copyright (c) 2017, https://github.com/devimust/bmu

# trace what gets executed (debugging purposes)
# set -x
# exit script when command fails
set -e
# exit status of last command returning non-zero exit code
set -o pipefail

reset_dst_dir(){
    OUTPUT=$(rm -Rf ./tests/testfiles/dst)
    OUTPUT=$(mkdir -p ./tests/testfiles/dst)
}

reset_srcdst_dir(){
    OUTPUT=$(rm -Rf ./tests/testfiles/src ./tests/testfiles/dst)
    OUTPUT=$(mkdir -p ./tests/testfiles/src ./tests/testfiles/dst)
}

delete_srcdst_dir(){
    OUTPUT=$(rm -Rf ./tests/testfiles/src ./tests/testfiles/dst)
}

# check folders/files exist
if [[ ! -e "./tests/testfiles" ]]; then
    echo "testfiles dir does not exist, are you running ./tests/run.sh ?" 1>&2
    exit 1
fi

if [[ ! -f "./bmu.sh" ]]; then
    echo "bmu.sh dir does not exist, are you running ./tests/run.sh ?" 1>&2
    exit 1
fi

echo "setting up source data"

# clean src/dst dirs
reset_srcdst_dir

# setup folders
OUTPUT=$(tar -xzf ./tests/testfiles/testfiles.tar.gz -C ./tests/testfiles/src)

OUTPUT=$(find ./tests/testfiles/src/. | wc -l)
if [ ! $OUTPUT -eq "63" ]; then
    echo "something went wrong with the source data" 1>&2
    exit 1
fi

echo "starting tests"

. ./tests/test-default-options.sh

delete_srcdst_dir

echo "all tests passed"
