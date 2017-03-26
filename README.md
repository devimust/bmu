# bmu - Back Me Up

This is a more compatible and generic approach using bash and linux tools to accomplish the same thing as [Back Me Up](https://github.com/devimust/back-me-up). Back Me Up makes it easy to backup your files and can check for changes.


## Installation

```bash
$ wget https://github.com/devimust/bmu/raw/master/bmu.sh
$ chmod +x ./bmu.sh
$ sudo mv ./bmu /usr/local/bin/bmu
```


## Usage

Using bmu can be as simple as:

`$ bmu /src /dst`

Options:

```
-c, --cache-dir             temporary cache folder to use as archiving medium
-d, --sub-dirs              only archive sub directories inside given source directory
-f, --force                 force process and bypass checking for changes
-h, --help                  show this help menu
-n, --dry-run               dry run to see what will happen
-p, --password PASSWORD     specify password to protect archive(s)
-s, --string-prefix PREFIX  prefix string to the destination archive file(s)
-t, --type TYPE             archive type to use (only zip currently available)
-v, --verbose               verbose output (debugging purposes)
```


## Examples

Given the following file structure:

```
/src/folder1/file1.txt
/src/folder1/file2.txt
/src/folder2/file3.txt
/src/folder2/file4.txt
```


### 1. Prefix and Sub-folders

Create or update backup sub-folders if changes found in `/src` (force backup by parsing `-f` flag).

`$ bmu -s pre123- -d /src /dst`

Should result in:

```
/dst/pre123-folder1.zip
/dst/pre123-folder1.zip.crc
/dst/pre123-folder2.zip
/dst/pre123-folder2.zip.crc
```


### 2. Password and Force

`$ bmu -f -p p@ss123 /src /dst`

Should result in:

```
/dst/dst.zip
/dst/dst.zip.crc
```

## Tests

`$ ./tests/run.sh`
