# Attribute Finder

`attrib-finder.sh` is a BASH script that will list
all the attributes declared withing a `workspace.yml` file in their "inline" format

Exaple output

> must be run inside a project's folder

```shell
> ./workspace-tools/attrib-finder/attrib-finder.sh
(d) | WS_FILE: workspace.yml
(d) | INLINE: php.version
(d) | INLINE: php.composer.major_version
(d) | INLINE: node.version
....
(d) | INLINE: database.bin.mtk.release_path
(d) | INLINE: services.php-base.environment.CREDLY_INVIQA_ID
(d) | INLINE: services.php-base.environment.GOOGLE_CLIENT_ID
...
(d) | PARENT: frontend.build.distribution_packages
(d) | CHILD0: frontend.build.distribution_packages.0
(d) | CHILD1: frontend.build.distribution_packages.1
(d) | CHILD2: frontend.build.distribution_packages.2
...
```
