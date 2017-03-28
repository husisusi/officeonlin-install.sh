# officeonline-install.sh
---
Script intended to build & install Office Online on Ubuntu 16.04 and Debian 8.7 systems.

Written by: Subhi H. & Marc C.

----
## GNUv3 Licence
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

### Idempotence
This script has been made idempotent: Only the required action will be executed if it is run several times on the same System in order to get to the expected state.

_Example_: when updating **LibreOffice** online to the latest version, **LibreOffice** compilation and installation steps will not be run as it is already installed.

## Parameters
Theses parameters describes the expected state of the system regarding LibreOffice Online installation.

**The installation can be tuned to your needs by changing theses variables.**
### LibreOffice:
- `lo_src_repo`: **LibreOffice** sources are downloaded from this location.
- `lo_version`: **LibreOffice** version to download. _Empty by default_.
When empty, the script will download the latest stable version available.
- `lo_dir`: **LibreOffice** sources directory. _`/opt/libreoffice` by default_.
- `lo_forcebuild`: A **boolean** to override idempotence and force *LibreOffice* compilation and installation. _`false` by default_.

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
- `lool_configure_opts`: free form string to add even more options ! _`--enable-debug` by default_. **For experts only!**

## Nota Bene
- All the script's output is logged in the file `/tmp/YYYYMMDD-HHmm_officeonline.log`. where `YYYYMMDD-HHmm` is the date (to the minute) when the script as been launched.

- Default parameters are values chosen by the maintainers of this script and not default values used by the softwares compiled here.

- If you ever need support for using this script, try to run it first with all parameters at default to get a reference point.

## Enjoy your free Office Online!
