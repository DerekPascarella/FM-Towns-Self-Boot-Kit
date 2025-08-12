# FM Towns Self-Boot Kit

A kit to build self-booting ISOs for the FM Towns.

This tool can be used to take a set of files (among which must include `IO.SYS`) and produce from them an ISO bootable on the FM Towns/FM Towns Marty, either via burned CD-R or ODE.

Example uses include...
- Modifying existing FM Towns software.
- Creating CD-ROM conversions of floppy disk games.
- Creating CD-ROM conversions of hard-drive-install-only games.

## Table of Contents
- [Current Version](#current-version)
- [Changelog](#changelog)
- [Usage](#usage)
- [Example Scenario](#example-scenario)

## Current Version
FM Towns Self-Boot Kit is currently at version [1.1](https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/releases/download/1.1/FM.Towns.Self-Boot.Kit.v1.1.zip).

## Changelog
- **Version 1.1 (2025-08-12)**
    - Improved status messages for enhanced readability.
    - New commandline parameter for target ISO file name added in order to run FM Towns Self-Boot Kit from commandline without requiremenet for user interaction.
    - New commandline parameter to run in unattended/non-interactive mode.
- **Version 1.0 (2025-08-11)**
    - Initial release.
 
## Usage
1. Extract the [latest release package](https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/releases/download/1.1/FM.Towns.Self-Boot.Kit.v1.1.zip) to any folder of your choosing.
2. Prepare a separate folder with contents to be used to generate an ISO.
   - Note that `IO.SYS` must reside in this folder in order to be treated as a proper FM Towns disc when the IPL loader patch step occurs.
4. Drag said folder onto `fmt_selfboot.exe` and watch as prompts and status message appear until process is complete.

FM Towns Self-Boot kit is designed for easy use directly from Windows File Explorer. However, it can also run in unattended/non-interactive mode.

```
fmt_selfboot.exe <disc_image_files> <iso_file_name> unattended
```

For example, in order to build `GAME.ISO` from the files in `C:\game_data\` without being prompted to enter an ISO file name, and without being prompted to press Enter to close the program, the following command would be used.

```
fmt_selfboot.exe C:\game_data\ GAME.ISO unattended
```

## Example Scenario
In this example scenario, a self-booting CD-ROM disc image for the floppy game "Gorby no Pipeline Daisakusen" will be generated. It's important to mention that the method used here is surely overkill, and the entirety of Towns System Software is not required on a single CD-ROM solely to launch this game. However, this scenario still serves as a good learning tool for those wishing to leverage FM Towns Self-Boot Kit.

First, the [HxC Floppy Emulator](https://hxc2001.com/download/floppy_drive_emulator/) software will be used to open the `Gorby no Pipeline Daisakusen.hfe` floppy disk image. After opening it, the "Disk Browser" feature will be used to see the contents of the disk image. Then, "Get Files" is clicked to extract its contents to a folder.

![](https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/blob/main/images/extract_floppy.png?raw=true)

With all 14 files extracted, the next step is to extract a version of a Towns System Software CD-ROM. Version 2.1 L40 will be used in this example because it's had a relatively high success rate for creating floppy disk game CD-ROM conversions.

Opening the CD-ROM image with a tool like [IsoBuster](https://www.isobuster.com/), extract the contents of the data track to a folder.

<img src="https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/blob/main/images/extract_towns_system_software.png?raw=true" width="800">

Once complete, both the original game's floppy disk files and the Towns System Software CD-ROM files will reside in two separate folders.

The next step requires copying all files from the extracted floppy disk folder to the extracted CD-ROM folder. If prompted at any point to overwrite existing files in the Towns System Software folder, it's up to the user's discretion which files should remain, and which should be overwritten.

Once all files are copied and reside together in one folder, it's time for the user to investigate the `AUTOEXEC.BAT` file. Consider the default `AUTOEXEC.BAT` from Towns System Software Version 2.1 L40.

```
01 - ECHO OFF
02 - SET TOMH=Q:\HELP
03 - SET ICN=Q:\
04 - SET PRNINF=Q:\HCOPY
05 - \HCOPY\COCO
06 - IF ERRORLEVEL 1 GOTO END
07 - \SIDEWORK\SIDEWORK
08 - \SYSINIT\SYSINIT
09 - IF ERRORLEVEL 1 GOTO EXIT
10 - \HCOPY\NSDDLOAD \HCOPY\NSDDLOAD.SCR
11 - IF ERRORLEVEL 1 GOTO END
12 - CONTROL -v
13 - GOTO EXIT
14 - :END
15 - \T_TOOL\DELVDISK
16 - \T_TOOL\REIPL
17 - :EXIT
```

In this example, line 12 will be replaced with `RUN386.EXE GOL.EXP` to launch the game software. Now, `AUTOEXEC.BAT` reads as follows.

```
01 - ECHO OFF
02 - SET TOMH=Q:\HELP
03 - SET ICN=Q:\
04 - SET PRNINF=Q:\HCOPY
05 - \HCOPY\COCO
06 - IF ERRORLEVEL 1 GOTO END
07 - \SIDEWORK\SIDEWORK
08 - \SYSINIT\SYSINIT
09 - IF ERRORLEVEL 1 GOTO EXIT
10 - \HCOPY\NSDDLOAD \HCOPY\NSDDLOAD.SCR
11 - IF ERRORLEVEL 1 GOTO END
12 - RUN386.EXE GOL.EXP
13 - GOTO EXIT
14 - :END
15 - \T_TOOL\DELVDISK
16 - \T_TOOL\REIPL
17 - :EXIT
```

After saving changes to `AUTOEXEC.BAT`, it's time to drag that folder onto `fmt_selfboot.exe` for processing and ultimately generating an ISO. Note that the program can also be executed via Windows console (e.g., `C:\path\to\fmt_selfboot.exe C:\path\to\disc\files\`), or via Linux/UNIX terminal (e.g., `perl /path/to/fmt_selfboot.pl /path/to/disc/files/`).

FM Towns Self-Boot Kit can also run without user input by adding a second parameter with the target ISO file name (e.g., `C:\path\to\fmt_selfboot.exe C:\path\to\disc\files\ game.iso`). By adding a third input parameter (`unattended`), the program will close without prompting the user to press Enter first (e.g., `C:\path\to\fmt_selfboot.exe C:\path\to\disc\files\ game.iso unattended`).

![](https://github.com/DerekPascarella/FM-Towns-Self-Boot-Kit/blob/main/images/tool_screenshot.png?raw=true)

Once complete, the ISO will reside in the same folder as `fmt_selfboot.exe` with the name specified by the user.

Note that this is just one example of using FM Towns Self-Boot Kit, but there are numerous others. Also note that users should expect quirks for each customized disc image they wish to author.
