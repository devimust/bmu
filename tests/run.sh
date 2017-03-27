#!/usr/bin/env bash
# Back me up tests. Copyright (c) 2017, https://github.com/devimust/bmu

# trace what gets executed (debugging purposes)
# set -x
# exit script when command fails
set -e
# exit status of last command returning non-zero exit code
set -o pipefail

print_header(){
    echo
    echo "******************************************"
    echo "* $1"
    echo "******************************************"
    echo
}

reset_dst_dir(){
    OUTPUT=$(rm -Rf ./tests/testfiles/dst)
    OUTPUT=$(mkdir -p ./tests/testfiles/dst)
}

reset_srcdst_dir(){
    OUTPUT=$(rm -Rf ./tests/testfiles/src ./tests/testfiles/dst)
    OUTPUT=$(mkdir -p ./tests/testfiles/src ./tests/testfiles/dst)
    OUTPUT=$(tar -xzf ./tests/testfiles/testfiles.tar.gz -C ./tests/testfiles/src)
    OUTPUT=$(find ./tests/testfiles/src/. | wc -l)
    if [ ! $OUTPUT -eq "63" ]; then
        echo "something went wrong with the source test data" 1>&2
        exit 1
    fi
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

print_header "setup"

echo "testing source data"

reset_srcdst_dir

echo "starting tests"

. ./tests/test-default-options.sh
. ./tests/test-subdirs.sh

delete_srcdst_dir

print_header "all tests passed"
