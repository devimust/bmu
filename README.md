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


## Examples

Given the following file structure:

```
/src/folder1/file1.txt
/src/folder1/file2.txt
/src/folder2/file3.txt
/src/folder2/file4.txt
```


### 1. Prefix and Subfolders

Create or update backup if changes found in `/src` (force backup by parsing `-f` flag).

`$ bmu -a pre123- -s /src /dst`

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
