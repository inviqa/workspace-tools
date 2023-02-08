# Attribute Finder

`attrib-finder.sh` is a BASH script that will list
all the attributes declared withing a `workspace.yml` file in their "inline" format

## What it does
1. Parse the `workspace.yml` file using `yq` and `jq` to collect the list of all the `yaml` attributes decalared
2. It collects the list of all the `inline` declared attributes: i.e. `attribute:('some.inline.attribute)`
3. It collects the list of all possible `inline` attribute `children` if any
4. It collects the list of all the `nested` declared attributes:

   ```yml
   some:
     nested:
        attribute: somevalue
   ```

5. Print the list of all the collected attributers in `inline` format

## Usage

Used this command to print the command's usage parameters

```shell
/path/to/attrib-finder.sh --help
```

### Exaples

#### Print the list of all declared attributes in `inline` format

```shell
> ./workspace-tools/attrib-finder/attrib-finder.sh --workspace-file /path/to/workspace.yml
php.version
php.composer.major_version
node.version
database.bin.mtk.release_path
services.php-base.environment_secrets.CREDLY_INVIQA_SECRET
services.php-base.environment_secrets.GOOGLE_CLIENT_SECRET
...
```

#### Print the list of all declared attributes with their type

```shell
> ./workspace-tools/attrib-finder/attrib-finder.sh --workspace-file /path/to/workspace.yml --debug 1
(d) | WS_FILE: workspace.yml
(d) | REQUIREMENT FOUND: /opt/homebrew/bin/yq
(d) | REQUIREMENT FOUND: /opt/homebrew/bin/jq
(d) | INLINE: php.version
(d) | INLINE: php.composer.major_version
(d) | INLINE: node.version
(d) | INLINE: database.bin.mtk.release_path
(d) | PARENT: services.php-base.environment_secrets
(d) | CHILD0: services.php-base.environment_secrets.CREDLY_INVIQA_SECRET
(d) | CHILD1: services.php-base.environment_secrets.GOOGLE_CLIENT_SECRET

...
```

#### Print the list of only the encrypted attributes

```shell
> ./workspace-tools/attrib-finder/attrib-finder.sh --workspace-file /path/to/workspace.yml --encrypted
services.php-base.environment_secrets.CREDLY_INVIQA_SECRET
services.php-base.environment_secrets.GOOGLE_CLIENT_SECRET
...
```

#### Print all ecrypted secrets in clear

```shell
~/Development/Workspace/workspace-tools/attrib-finder/attrib-finder.sh -e | xargs -I % ws config dump --key=%
string(52) "<decrypted-secret>"
string(51) "<decrypted-secret>"
string(39) "<decrypted-secret>"
```
