#!/usr/bin/perl -w

## @file
# Move recordings out of the current day folder into archive folder.
# Expects config/archive.cfg to contain
#
# [archive]
# today_dir = <path to the camera output directory>
#
# followed by one or more
#
# [type.N]  - replace N with a number
# archive_dir = <directory at the base of the archive tree>
# basename    = <Initial name before date and timestamp>
# extension   = <file extension, including .>
#
# note that
#
# [Spanish Inquisition]
# weapons = fear, surprise, ruthless efficiency, an almost fanatical devotion to the Pope, and nice red uniforms
#
# IS NOT expected.

use strict;
use lib qw(/var/www/webperl);

use Webperl::ConfigMicro;
use Webperl::Utils qw(path_join);

use DateTime;
use File::Path qw(make_path);
use FindBin;             # Work out where we are
my $path;
BEGIN {
    $ENV{"PATH"} = "/bin:/usr/bin"; # safe path.

    # $FindBin::Bin is tainted by default, so we may need to fix that
    # NOTE: This may be a potential security risk, but the chances
    # are honestly pretty low...
    if ($FindBin::Bin =~ /(.*)/) {
        $path = $1;
    }
}

# Month names to simplify month directory name generation
my @months = ( "None", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");


## @fn @ make_destination($file, $today, $settings)
# Generate the archive directory name and filename for the specified
# source file.
#
# @param file     The full name, including path, of the source file.
# @param today    A reference to a DateTime object for today's date.
# @param settings A reference to a hash of settings for the archive operation.
# @return The archive directory to write the file into, and the filename to
#         use. Note that this will only return data for previous days, and
#         it will return undef for files with datestamps that match the date
#         in $today.
sub make_destination {
    my $file       = shift;
    my $today      = shift;
    my $settings   = shift;

    my ($filename) = $file =~ m|/($settings->{basename}.+)$|;
    die "Unable to locate valid filename in $file.\n"
        unless($filename);

    my ($year, $month, $day) = $filename =~ /^$settings->{basename}(\d{4})-(\d\d)-(\d\d)/;

    my $filedate = DateTime -> new(year => $year, month => $month, day => $day) -> truncate( to => 'day' );
    return undef
        if(!$settings -> {"realtime"} && $filedate == $today);

    my @parts = ( $settings -> {"archive_dir"} );
    push(@parts, $year, $month." ".$months[$month], "$year$month$day")
	unless($settings -> {"flat"});

    return (path_join(@parts), $filename);
}


## @fn void archive($sourcedir, $settings)
# Move files that match the specified basename and extension out of the
# source directory into the appropriate subdirectory of the archive.
#
# @param sourcedir The directory containing the files to archive.
# @param settings  A reference to a hash of settings for the archive operation.
sub archive {
    my $sourcedir  = shift;
    my $settings   = shift;

    my $today = DateTime -> today();

    my @files = glob(path_join($sourcedir, $settings -> {"basename"}."*".$settings -> {"extension"}));

    my @tomove = ();
    foreach my $file (@files) {
        my ($destdir, $filename) = make_destination($file, $today, $settings);
        if(!$destdir) {
	    print "Skipping $file...\n"; # Allow skipping of files
	    next;
	}

        print "Moving $filename to $destdir...\n";
        make_path($destdir)
            unless(-d $destdir);

        rename($file, path_join($destdir, $filename))
            or die "Unable to move $filename: $!\n";
    }
}

my $settings = Webperl::ConfigMicro -> new(path_join($path, "config", "archive.cfg"))
    or die "Unable to load configuration file: ".$Webperl::SystemModule::errstr."\n";

# Process the sections of the config, skipping anything that isn't a type.N
# configuration section.
foreach my $section (keys(%{$settings})) {
    next unless($section =~ /^type.\d+$/);

    archive($settings -> {"archive"} -> {"today_dir"}, $settings -> {$section});
}
