# officeonline-install.sh v2.5.1
---
Script intended to build & install Office Online on moderns Ubuntu and Debian systems.

Written by: Marc C. & Subhi H.

----

## Summary
* [GNUv3 Licence](#gnuv3-licence)
* [Requirements](#requirements)
* [Notice](#notice)
* [Default Installation](#default-installation)
  * [Command line usage](#command-line-usage)
  * [Configuration file](#configuration-file)
  * [Sets](#sets)
  * [Versions](#versions)
* [Default Installation](#default-installation)
* [Idempotence](#idempotence)
* [Parameters](#parameters)
  * [Global](#global-parameters)
  * [Sets](#set-parameters)
  * [LibreOffice](#libreoffice)
  * [Poco](#poco)
  * [Lool](#lool)
    * [Sources status](#sources-status)
    * [Compilation options](#compilation-options)
* [Debug](#debug)
* [Nota Bene](#nota-bene)

## GNUv3 License
> This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
> This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

## Requirements
- The script requires a **minimum of 3.7 GB of RAM installed** to run.
- First installation requires about **13 GB** of available space on the system.

## Notice
**THE FIRST INSTALLATION WILL TAKE A VERY, VERY LONG TIME!**

... So take your favorite mug, and make yourself a nice cup of coffee/tea while you go watching your favorites movies. :smile:

## Default Installation
You might see errors during the installation, just ignore them.

It will install libreoffice in `/opt/libreoffice`, Poco in `/opt/poco` and onlineOffice in `/opt/online`

Your can manage your service using systemd: `systemctl start|stop|restart|status loolwsd.service`

### Command line usage
Since v2.4 the script accept the following usage:

`officeonline-install.sh [-h][-c file|variable definition][-f lo|poco|lool][-l VERSION][-o COMMIT][-p VERSION]`

- Options:
  - `-c, --config /a/configuration/file|variable=value`

      Load a script configuration file OR directly a variable and its value to override it
      from the loaded configuration.
      _This option can be repeated._

  - `-f, --force lo|poco|lool`

      Specify a component to build anyway.
      Support some aliases for LibreOffice core and Libreoffice Online
      _This option can be repeated._

  - `-h, --help`

      display this help and exit

- Thoses options have been kept for backward compatibility and _may be removed in future releases_:

  - `-l, --libreoffice_commit)=COMMIT`

      Libreoffice COMMIT - short/full hash
    **Equivalent of `-c lo_src_commit=COMMIT`**

  - `-o, --libreoffice_online_commit)=COMMIT`

      Libreoffice Online COMMIT - short/full hash.
    __Equivalent of `-c lool_src_commit=COMMIT`__

  - `-p, --poco_version)=VERSION`

      Poco Version
    __Equivalent of `-c poco_version=VERSION`__

### Configuration file
Since v2.4 the script search for an external configuration file that will override parts or all the default configuration.

The script search for the file named `officeonline-install.cfg` in the following places in that order:
1. The file specified from the command line with the `--config` option. It can be of any name.
1. The __current working directory__ _except when it's the script's_ directory.
2. The __user's home__ directory
3. The __/etc/loolwsd/__ directory
4. The __script's directory__

Only the first file found is loaded.

__INFO:__ A fully commented configuration file is in the script's directory available as a template or an example.

### Sets
Since v2.1, it is possible to choose a **Set**.
A set is an duo of branches from both LibreOffice core and online git repositories that are known to create a smooth LO-Online experience.

**By default latest version available of collabora**

### Versions

Its possible to pin exact version of the services used, like this:

`./officeonline-install.sh -l 5.3.1.2 -c lool_src_commit=47c01440ba794d2ea953d6ac1b80f7e42769f4e -c poco_version=1.7.8p2`

There is also a help:

`./officeonline-install.sh -h`

## Idempotence
This script has been made idempotent: Only the required action will be executed if it is run several times on the same System in order to get to the expected state.

_Example_: when updating **LibreOffice online** to the latest version, **LibreOffice** compilation and installation steps will __not__ be run as it is already installed.

## Parameters
These parameters describes the expected state of the system regarding LibreOffice Online installation.

**The installation can be tuned to your needs by changing these variables.**

### Global Parameters:
Affect the whole build.
- `distrib_name`: A name for a list of build options for LibreOffice. The distribution is a file that may be created from scratch and changed by the script _'LibreOfficeOnline' by default_
- `allowed_domains`: Space separated list of domains allowed to use the LibreOffice-Online service. __dots escaping is processed by the script__.
  - __Note:__ Removing domains from the configuration file __is not supported__. Unwanted domains still need to be removed manually in the configuration file. `/etc/loolwsd/loolwsd.xml` _by default_.

### Set Parameters:
Affect how the script chooses the best set of commits to use for core and online.
- `set_name`: used to locate branchs folders in the libreoffice project. _'collabora' by default_
- `set_core_regex`: regulax expression used to find the branch name for core _'cp-' by default._
- `set_online_regex`: regulax expression used to find the branch name for online _'collabora-online' by default._
- `set_version` can be used **if both** branch name contains a common version number.
Else, latest version available for each project will be used. _empty by default_

### LibreOffice:
For Idempotence, LO's status is defined by its sources' commit id.
- `lo_dir`: The installation directory for _Lo_. _`/opt/online` by default_.
- `lo_forcebuild`: A **boolean** to override idempotence and force *LibreOffice* compilation and installation. _`false` by default_.
- `lo_configure_opts`: comma separated list of build options. Added to the distro. _`` by default_. **For experts only!**
_Each update of the sources by the script will trigger a **lO** compilation & installation_
- `lo_src_repo`: the Git repository _"https://github.com/LibreOffice/core.git"_
- `lo_src_branch`: an existing branch name. It pull the latest Tag available _`master` by default_
- One of the 2:
  - `lo_src_commit`:  the id of a git commit in the selected branch. _`empty` by default_
  - `lo_src_tag`: a tag in the selected branch. _`empty` by default_

If more than one is defined, a choice is made:
- _choice precedence_: **Commit** over **tag**

### POCO:
Poco is an opensource C++ library for network based project. It is required by LibreOffice Online.
- `poco_version`: a specific version to download, compile and install. _Fetch the latest stable release from  https://pocoproject.org/ by default_.
- `poco_dir`: The installation directory for poco. _`/opt/poco-${poco_version}-all` by default._
- `poco_forcebuild`: A **boolean** to override idempotence and force *POCO* compilation and installation. _`false` by default_.


### Lool
Lool (LibreOffice Online) in a project to bring a opensource Office solution for web editing.
- `lool_dir`: The installation directory for _Lool_. _`/opt/online` by default_.
- `lool_forcebuild`: A **boolean** to override idempotence and force *LibreOffice Online* compilation and installation. _`false` by default_.
#### Sources status:
For Idempotence, Lool's status is defined by its sources' commit id.

_Each update of the sources by the script will trigger a **lool** compilation & installation_
- the Git repository: `lool_src_repo` _"https://github.com/LibreOffice/online.git"_
- One of the 3:
  - `lool_src_branch`: an existing branch name. It pull the latest commit available _`master` by default_
  - `lool_src_commit`:  the id of a git commit. _`empty` by default_
  - `lool_src_tag`: a tag in the git repository._`empty` by default_

If more than one is defined, a choice is made:
- _choice precedence_: **Commit** over **tag** over **branch**

#### Compilation options:
The following parameters are options passed to the configuration script before compilation.
- `lool_logfile`: `/var/log/loolwsd.log`
- `lool_maxdoc`: Maximum number of _simultaneously_ opened documents for Lool. _`100` by default._
- `lool_maxcon`: Maximum number of _simultaneously_ opened connections for Lool. _`200` by default._
- `lool_configure_opts`: comma separated list of build options. Added to the distro. _Empty by default_. **For experts only!**
- `lool_prefix`: The base directory from where the directory tree is generated. Used to install the application _'/usr' by default_
- `lool_sysconfdir`: The base directory from where the application's is located _'/etc' by default_
- `lool_localstatedir`: The base directory from where the application's state files are located. _'/var' by default_

## Debug
Can be enabled by running `sudo ./officeonline-install.sh -c lool_configure_opts='--enable-debug' -f lool`

or

add --enable-debug to lool_configure_opts='' in officeonline-install.cfg before compiling. Don't forget to remove the #

Change filesystem allow="false" to "true" in /opt/online/loolwsd.xml

Enabling debug can pose a security risk. Use it only for testing.

## Nota Bene
- All the script's output is logged in the folder `$PWD/YYYYMMDD-HHmm_officeonline-install `. where `YYYYMMDD-HHmm` is the date at the minute the script as been launched.

- `Maxdoc` & `Maxcon` are built-in limitations in WebSocket and intended to guarantee a good QoS and limit resources consumption on the host. *If you intend to change this parameters, take into account that __1 doc opened is around 20MB of RAM used.__*

- Default parameters are values chosen by the maintainers of this script and not default values used by the softwares compiled here.

- If you ever need support for using this script, try to run it first with all parameters at default to get a reference point.

## Enjoy your free Office Online!
