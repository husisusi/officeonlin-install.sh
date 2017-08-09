#!/bin/bash
help_menu() {
  echo "Usage:

  ${0##*/} [-h][-c file|variable definition][-f lo|poco|lool][-l VERSION][-o COMMIT][-p VERSION]

Options:
  -c, --config /a/configuration/file|variable=value
    Load a script configuration file OR directly a variable and its value to override it
    from the loaded configuration
    This option can be repeated.

  -f, --force lo|poco|lool
    Specify a component to build anyway.
    Support some aliases for LibreOffice core and Libreoffice Online
    This option can be repeated.

  -h, --help
    display this help and exit

Thoses options have been kept for backward compatibility and may be removed
in future releases:

  -l, --libreoffice_commit)=COMMIT
    Libreoffice COMMIT - short/full hash
  Equivalent of -c lo_src_commit=COMMIT

  -o, --libreoffice_online_commit)=COMMIT
    Libreoffice Online COMMIT - short/full hash
  Equivalent of -c lool_src_commit=COMMIT

  -p, --poco_version)=VERSION
    Poco Version
  Equivalent of -c poco_version=VERSION
  "
}
