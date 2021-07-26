# setboot

A simple Linux command line tool to modify the UEFI boot order on dual boot or multi boot systems so that an alternate operating system can be booted by default. 

## Installation

### Prerequisites
The `efibootmgr` tool must be installed, which is ussed to query and modify the boot manager settings. On Ubuntu 20.04 this can be installed with:
```
$ apt install efibootmgr
```

Install the [crystal compiler](https://crystal-lang.org/install/)

### Building

Check out the source from [](https://github.com/robdavid/setboot).

Build the binary with

```
$ cd setboot
$ shards build
```

Then copy to a directory in your PATH, eg.
```
$ cp bin/setboot /usr/local/bin
```

## Usage

Basic usage is to run the command with a single argument to identify the name of the boot entry you want to move to the top of the boot order, eg.
```
$ setboot win
```
This will move the first active boot entry containing the string "win" to the start of the boot order. Entries are matching by searching for a case insensitive substring. Eg. "win" will match with the windows boot manager which is usually named "Windows Boot Manager".

### Other options
 * `-n` will set the boot entry for the next boot only
 * `-l` will list the available boot entries in boot order
 * `-h` displays help 

## Contributing

1. Fork it (<https://github.com/your-github-user/setboot/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Rob David](https://github.com/robdavid) - creator and maintainer
