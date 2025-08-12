#!/usr/bin/perl
#
# FM Towns Self-Boot Kit v1.1
# Written by Derek Pascarella (ateam)
#
# A kit to build self-booting ISOs for the FM Towns.

# Include necessary modules.
use strict;
use FindBin;
use File::Find;
use File::Which;

# Set version.
my $version = "1.1";

# Detect OS type.
my $os = "Linux";

if($^O =~ /MSWin/)
{
	$os = "Windows";
}

# Store program's folder path.
my $working_folder = $FindBin::Bin;
$working_folder =~ s/\//\\/g if($os eq "Windows");

# Perform sanity check.
if($os eq "Linux" && !which("mkisofs"))
{
	print_error("The mkisofs command is not in your path.");
	exit;
}
elsif($os eq "Windows" && !-e $working_folder . "/helpers/mkisofs.exe")
{
	print_error("The mkisofs.exe utility is missing from the \"helpers\" folder.");
	exit;
}
elsif(!-e $working_folder . "/helpers/IPL.BIN")
{
	print_error("IPL.BIN missing from the \"helpers\" folder.");
	exit;
}

# Initialize input variables.
my $input_folder = $ARGV[0];
my $iso_name = $ARGV[1];
my $non_interactive = $ARGV[2];

# Throw error if input folder is unreadable, not a folder, or doesn't exist.
if(!-e $input_folder || !-d $input_folder || !-R $input_folder)
{
	print_error("Specified input folder is either unreadable, not a folder, or doesn't exist.");
	exit;
}

# Throw error if IO.SYS not found in input folder.
if(!-e $input_folder . "/IO.SYS")
{
	print_error("Specified input folder does not contain the necessary \"IO.SYS\" file.");
	exit;
}

# Initialize file/folder counters.
my $total_files = 0;
my $total_folders = 0;

# Count total number of files/folders in input folder.
find(
	sub {
		return if $File::Find::name eq $input_folder;

		if(-d $_)
		{
			$total_folders ++;
		}
		elsif(-f $_)
		{
			$total_files ++;
		}
	},
	$input_folder
);

# Status message.
print "\nFM Towns Self-Boot Kit v" . $version . "\n";
print "Written by Derek Pascarella (ateam)\n\n";
print "Detected OS: " . $os . "\n\n";
print "Using input path " . $input_folder . ":\n";
print " - Total folder(s): " . $total_folders . "\n";
print " - Total file(s): " . $total_files . "\n\n";

# Change to program's folder.
chdir $working_folder;

# Status message.
print "This program will generate an ISO in the following folder:\n";
print " - " . $working_folder . "\n\n";

# Prompt user for ISO file name if none passed as input parameter.
if($iso_name eq "")
{
	print "Please specify a file name for the ISO (e.g., \"Game.iso\"): ";
	chop($iso_name = <STDIN>);
	print "\n";
}

# Clean up user-specified ISO file name.
$iso_name =~ s/^\s+|\s+$//g;
$iso_name =~ s/\.(?!iso$)[^.]+$//i;
$iso_name .= ".iso" unless($iso_name =~ /\.iso$/i);

# Construct mkisofs command for both Windows (with helper utility) and Linux.
my $mkisofs_command;

if($os eq "Windows")
{
	$mkisofs_command = "helpers\\mkisofs.exe -iso-level 1 -V FMT_DISC -A \"FMTOWNS\" -publisher \"ATEAM\" -N -T -o \"$iso_name\" \"$input_folder\" > NUL 2>&1";
}
else
{
	$mkisofs_command = "mkisofs -iso-level 1 -V FMT_DISC -A \"FMTOWNS\" -publisher \"ATEAM\" -N -T -o \"$iso_name\" \"$input_folder\" > /dev/null 2>&1";
}

# Status message.
print " -> Generating ISO...\n\n";

# Execute mkisofs command.
system($mkisofs_command);

# Error encountered during ISO build.
if($? != 0)
{
	my $exit_code = $? >> 8;
	print_error("Error: mkisofs failed with exit code " . $exit_code , " (see full command below).\n" . $mkisofs_command);
	exit;
}

# Status message.
print " -> ISO successfully generated!\n\n";
print " -> Injecting IPL loader into ISO...\n\n";

# Patch ISO with IPL loader.
my $ipl_bin = &read_bytes("helpers/IPL.BIN");
patch_bytes($working_folder . "/" . $iso_name, $ipl_bin, 0);
my ($lba, $sectors, $bytes) = ipl_patch($working_folder . "/" . $iso_name);

# Status message.
print " -> IPL injected successfully!\n";
print "     - LBA: $lba\n";
print "     - Sectors: " . $sectors . "\n";
print "     - IO.SYS size: " . $bytes . " bytes\n\n";
print "Your FM Towns ISO is ready for use!\n\n";

# Wait to close window.
if($non_interactive ne "unattended")
{
	print "Press Enter to close this window...\n";
	<STDIN>;
}

# Subroutine to locate IO.SYS (or a specified filename) in the ISO9660 root,
# compute its starting LBA and 2048-byte sector count, and write those values
# into the IPL at offset 0x20 as two little-endian 32-bit integers.
#
# 1st parameter - Full path of ISO file to analyze and patch.
# 2nd parameter - Optional target filename to locate (default is IO.SYS).
#
# Returns - List of three values:
#           1) Starting LBA of target file (decimal).
#           2) Sector count of target file using 2048-byte sectors (decimal).
#           3) Size of target file in bytes (decimal).
#
# Notes
# - This routine validates the ISO9660 Primary Volume Descriptor at LBA 16.
# - The root directory record is parsed from byte offset 156 of the PVD.
# - The search is case-insensitive and accepts both NAME and NAME;1.
# - On success, 8 bytes are written at 0x20: LBA (LE32) then sector count (LE32).
sub ipl_patch
{
	my $iso_path = $_[0];
	my $wanted_name = $_[1];

	$wanted_name = "IO.SYS" if(!defined $wanted_name || $wanted_name eq "");

	my $SECTOR = 2048;

	# Open ISO and read Primary Volume Descriptor (PVD) at LBA 16.
	open(my $fh, "<:raw", $iso_path) or die "ipl_patch() failed to open file '$iso_path': $!";
	binmode($fh);
	seek($fh, 16 * $SECTOR, 0) or die "ipl_patch() failed: cannot seek to PVD\n";
	read($fh, my $pvd, $SECTOR) == $SECTOR or die "ipl_patch() failed: cannot read PVD\n";

	# Verify ISO9660 PVD signature and type.
	my $vol_type = ord substr($pvd, 0, 1);
	my $std_id = substr($pvd, 1, 5);

	if(!($vol_type == 1 && $std_id eq "CD001"))
	{
		die "ipl_patch() failed: not an ISO9660 PVD at LBA 16\n";
	}

	# Extract root directory record from PVD (begins at byte offset 156).
	my $root_off = 156;
	my $dr_len = ord substr($pvd, $root_off, 1);

	if($dr_len <= 0)
	{
		die "ipl_patch() failed: invalid root directory record length\n";
	}

	my $root_dr = substr($pvd, $root_off, $dr_len);

	# Store little-endian extent LBA.
	my $root_lba = unpack("V", substr($root_dr,  2, 4));

	# Store little-endian data length in bytes.
	my $root_size = unpack("V", substr($root_dr, 10, 4));

	# Scan root directory extent for the requested filename.
	my ($file_lba, $file_size) = find_iso_entry($fh, $root_lba, $root_size, $wanted_name);
	close($fh);

	if(!defined $file_lba)
	{
		die "ipl_patch() failed: could not find '$wanted_name' in ISO root\n";
	}

	# Compute 2048-byte sector count using ceiling division.
	my $sectors = int(($file_size + $SECTOR - 1) / $SECTOR);

	# Compose 8-byte little-endian payload: LBA (4) + sector count (4).
	my $hex_payload = unpack("H*", pack("V V", $file_lba, $sectors));

	# Patch payload at absolute offset 0x20 in the ISO.
	patch_bytes($iso_path, $hex_payload, 0x20);

	# Return useful values to caller.
	return($file_lba, $sectors, $file_size);
}

# Subroutine to scan a single ISO9660 directory extent and return the extent
# LBA and file size for a given filename. Search is case-insensitive and
# accepts both NAME and NAME;1. Special entries 0x00 and 0x01 are skipped.
#
# 1st parameter - Open filehandle for the ISO (binary mode).
# 2nd parameter - Starting LBA of the directory extent to scan.
# 3rd parameter - Total byte length of the directory extent.
# 4th parameter - Target filename to locate (e.g., IO.SYS).
#
# Returns - On success, a two-element list:
#           1) File extent LBA (decimal).
#           2) File size in bytes (decimal).
#           On failure, returns empty list.
sub find_iso_entry
{
	my $fh = $_[0];
	my $extent_lba = $_[1];
	my $data_len = $_[2];
	my $wanted_name = $_[3];

	my $SECTOR = 2048;

	# Build acceptable name set (NAME and NAME;1, uppercased).
	my $want_uc = uc $wanted_name;
	my %accept = map { $_ => 1 } ($want_uc, $want_uc . ";1");

	# Iterate sector-by-sector across the directory extent.
	my $remaining = $data_len;
	my $lba = $extent_lba;

	while($remaining > 0)
	{
		seek($fh, $lba * $SECTOR, 0) or die "find_iso_entry() failed: cannot seek directory sector\n";
		read($fh, my $buf, $SECTOR) == $SECTOR or die "find_iso_entry() failed: cannot read directory sector\n";

		$lba ++;
		$remaining -= $SECTOR;

		# Walk variable-length directory records within the sector.
		my $i = 0;

		while($i < $SECTOR)
		{
			my $dr_len = ord substr($buf, $i, 1);

			# A zero length indicates no more records in this sector.
			last if($dr_len == 0);

			my $dr = substr($buf, $i, $dr_len);
			my $name_len = ord substr($dr, 32, 1);
			my $name = substr($dr, 33, $name_len);

			# Skip special self/parent entries with names 0x00 and 0x01.
			my $is_special = ($name_len == 1) && ((ord($name) == 0) || (ord($name) == 1));

			if(!$is_special)
			{
				my $name_uc = uc $name;

				# Match either NAME or NAME;1.
				if(exists $accept{$name_uc})
				{
					# Store little-endian extent LBA.
					my $file_lba = unpack("V", substr($dr,  2, 4));

					# Store little-endian file size.
					my $file_size = unpack("V", substr($dr, 10, 4));

					return ($file_lba, $file_size);
				}
			}

			# Advance to next directory record within this sector.
			$i += $dr_len;
		}
	}

	# Not found in provided directory extent.
	return;
}

# Subroutine to read a specified number of bytes (starting at the beginning) of a specified file,
# returning hexadecimal representation of data.
#
# 1st parameter - Full path of file to read.
# 2nd parameter - Number of bytes to read (omit parameter to read entire file).
sub read_bytes
{
	my $input_file = $_[0];
	my $byte_count = $_[1];

	if($byte_count eq "")
	{
		$byte_count = (stat $input_file)[7];
	}

	open(my $filehandle, '<:raw', $input_file) or die "read_bytes() failed to open file '$input_file': $!";
	binmode($filehandle);

	my $bytes_read = read($filehandle, my $bytes, $byte_count);

	if(!defined($bytes_read))
	{
		die "read_bytes() failed to read from file '$input_file': $!";
	}
	elsif($bytes_read != $byte_count)
	{
		die "read_bytes() read only $bytes_read of $byte_count bytes from '$input_file'.";
	}

	close($filehandle);
	
	return(unpack 'H*', $bytes);
}

# Subroutine to write a sequence of hexadecimal values at a specified offset (in decimal format) into
# a specified file, as to patch the existing data at that offset.
#
# 1st parameter - Full path of file in which to insert patch data.
# 2nd parameter - Hexadecimal representation of data to be inserted.
# 3rd parameter - Offset at which to patch.
sub patch_bytes
{
	my $output_file = $_[0];
	(my $hex_data = $_[1]) =~ s/\s+//g;
	my $patch_offset = $_[2];

	if(length($hex_data) % 2 != 0)
	{
		die "patch_bytes() failed: hex string must have even length\n";
	}

	my $patch_byte_length = length($hex_data) / 2;
	my $file_size = (stat $output_file)[7];

	if($file_size < $patch_offset + $patch_byte_length)
	{
		die "patch_bytes() failed: patch range exceeds file size\n";
	}

	open(my $filehandle, '+<:raw', $output_file) or die "patch_bytes() failed to open file '$output_file': $!";
	binmode($filehandle);
	seek($filehandle, $patch_offset, 0);

	for(my $i = 0; $i < length($hex_data); $i += 2)
	{
		print $filehandle pack("H*", substr($hex_data, $i, 2));
	}

	close($filehandle);
}

# Subroutine to print a standard formatted error message.
sub print_error
{
	my $message = $_[0];

	print "\nFM Towns Self-Boot Kit v" . $version . "\n";
	print "Written by Derek Pascarella (ateam)\n\n";
	print "Error: " . $message . "\n";
	print "\nPress Enter to close this window...\n";
	<STDIN>;
}