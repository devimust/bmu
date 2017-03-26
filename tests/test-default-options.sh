#!/usr/bin/env bash
# Back me up tests. Copyright (c) 2017, https://github.com/devimust/bmu

echo "test default archive options work"

OUTPUT=$(./bmu.sh ./tests/testfiles/src ./tests/testfiles/dst)
OUTPUT=$(find ./tests/testfiles/dst | wc -l)
if [ ! "$OUTPUT" == "3" ]; then
    echo "error wit wc" 1>&2
    exit 1
fi
OUTPUT=$(du -sb ./tests/testfiles/dst | awk '{print $1;}')
if [ ! "$OUTPUT" == "1388970" ]; then
    echo "error with du" 1>&2
    exit 1
fi

MOD_TIME_a_1=$(stat -c '%y' ./tests/testfiles/dst/src.zip)
MOD_TIME_a_2=$(stat -c '%y' ./tests/testfiles/dst/src.zip.crc)

echo "test no change to src results in no change to dst"

OUTPUT=$(./bmu.sh ./tests/testfiles/src ./tests/testfiles/dst)
OUTPUT=$(find ./tests/testfiles/dst | wc -l)
if [ "$OUTPUT" != "3" ]; then
    echo "error wit wc" 1>&2
    exit 1
fi
OUTPUT=$(du -sb ./tests/testfiles/dst | awk '{print $1;}')
if [ "$OUTPUT" != "1388970" ]; then
    echo "error with du" 1>&2
    exit 1
fi

MOD_TIME_b_1=$(stat -c '%y' ./tests/testfiles/dst/src.zip)
MOD_TIME_b_2=$(stat -c '%y' ./tests/testfiles/dst/src.zip.crc)

if [ "$MOD_TIME_a_1" != "$MOD_TIME_b_1" ]; then
    echo "error with file timestamps" 1>&2
    exit 1
fi

if [ "$MOD_TIME_a_2" != "$MOD_TIME_b_2" ]; then
    echo "error with file timestamps" 1>&2
    exit 1
fi

echo "test that a change to src results in a change to dst"

OUTPUT=$(echo $(date) > ./tests/testfiles/src/a/tmp_date.txt)
OUTPUT=$(./bmu.sh ./tests/testfiles/src ./tests/testfiles/dst)
OUTPUT=$(find ./tests/testfiles/dst | wc -l)
if [ "$OUTPUT" != "3" ]; then
    echo "error wit wc" 1>&2
    exit 1
fi
OUTPUT=$(du -sb ./tests/testfiles/dst | awk '{print $1;}')
if [ "$OUTPUT" != "1389196" ]; then
    echo "error with du" 1>&2
    exit 1
fi

MOD_TIME_c_1=$(stat -c '%y' ./tests/testfiles/dst/src.zip)
MOD_TIME_c_2=$(stat -c '%y' ./tests/testfiles/dst/src.zip.crc)

if [ "$MOD_TIME_a_1" == "$MOD_TIME_c_1" ]; then
    echo "error with file timestamps" 1>&2
    exit 1
fi

if [ "$MOD_TIME_a_2" == "$MOD_TIME_c_2" ]; then
    echo "error with file timestamps" 1>&2
    exit 1
fi

reset_dst_dir
