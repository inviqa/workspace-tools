# Workspace Key Cycle

`wskeycycle.sh` is script written in BASH used to automate
a Workspace project's Development Environment Key rotation

## What it does

1. Creates a backup of the project's `workspace.yml` and `workspace.override.yml`
    a. `workspace.yml.orig`
    b. `workspace.override.yml.orig`
2. Reads all the encrypted secrets from the project's `workspace.yml`
3. Decrypts all the secrets using the `key('default'):` stored in the project's `workspace.override.yml`
4. Replaces the `key('default'):` in the project's `workspace.override.yml`
with a randomly generated Developement Environment Key
5. Reencrypt all the secrets with the new Development key
6. Saves all the new encrypted secretes in the project's `workspace.yml`

## Usage

Used this command to print the command's usage parameters

```shell
/path/to/wskeycycle.sh --help
```

### Development Key rotation

#### Single-repo projects

> Without any parameter `wskeycycle.sh` will generate a new random Development Key

```shell
cd project/directory/
/path/to/wskeycycle.sh
```

#### Multi-repo project

A multi-repo project is probably sharing the same Development Key
between the various repositories.

`wskyecycle.sh` can accept the `--development-key-file <file>` parameter
to specify what Development Key to use (instead of generating a random key)

```shell
# Generate a new random Development Key and store it in a plaintext file
ws secret generate-random-key > ~/random.key
cd project/directory/
# Use the `random.key` file to reencrypt your project's secrets
/path/to/wskeycycle.sh --development-key-file ~/random.key
```

> dont' forget to delete the ~/random.key file
> once you completed the rotation on all repositories

## Failing key rotation

In case of a failing key rotation the `workspace.yml`
and `workspace.override.yml` could be partially compromised.

You can restore the original files and enable
two levels of debugging to sort out the occurring issue.

### How to restore the original Workspace files

> During the Development Key rotation the original Workspace files
> are backed-up as `.origin` files

To restore those files in case of a failed rotation

```shell
cd project/directory/
/path/to/wskeycycle.sh --restore
```

### Debugging

It's possinle to tune the debugging verbosity setting
in the script itself the `DEBUG=` environment

```shell
/path/to/wskeycycle.sh --debug 0|1|2
```

> DEBUG=0 # show only command errors
> DEBUG=1 # show progress output
> DEBUG=2 # show all computed steps output
