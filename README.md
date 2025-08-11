# FM Towns Self-Boot Kit

A kit to build self-booting ISOs for the FM Towns.

This tool can be used to take a set of files (among which must include `IO.SYS`) and produce them from an ISO bootable on the FM Towns/FM Towns Marty, either via burned CD-R or ODE.

Example uses include...
- Modifying existing FM Towns software.
- Creating CD-ROM conversions of floppy disk games.
- Creating CD-ROM conversions of hard-drive-install-only games.

## Table of Contents
TOC will go here.

## Current Version
FM Towns Self-Boot Kit is currently at version [1.0](https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/releases/download/1.0/FM.Towns.Self-Boot.Kit.v1.0.zip).

## Changelog
- **Version 1.0 (2025-08-11)**
    - Initial release.
 
## Usage
1. Extract the [latest release package](https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/releases/download/1.0/FM.Towns.Self-Boot.Kit.v1.0.zip) to any folder of your choosing.
2. Prepare a separate folder with contents to be used to generate an ISO.
   - Note that `IO.SYS` must reside in this folder in order to be treated as a proper FM Towns disc when the IPL loader patch step occurs.
4. Drag said folder onto `fmt_selfboot.exe` and watch as prompts and status message appear until process is complete.

## Example Scenario
Example scenario will go here.
