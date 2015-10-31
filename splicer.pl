#!/usr/bin/perl -w


use strict;
use lib qw(/var/www/webperl);

use Webperl::ConfigMicro;
use Webperl::Utils qw(path_join);

use File::Path qw(make_path);
use List::Util qw(all);
use Time::Local;
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


use Data::Dumper;


## @fn $ name_to_epoch($name)
# Given a filename, generate a timestamp based on the date and
# time encoded in the filename. If the file does note contain a date
# and time of the format YYYY-MM-DD_HH-MM-SS (separators optional),
# this will warn acout it and return nothing.
#
# @param name     The name of the file to generate the timestamp from.
# @return The number of seconds since the epoch on suc success, undef on error.
sub name_to_epoch {
    my $name     = shift;

    #                      0           1           2         3          4          5
    my @parts = $name =~ /(\d{4})[-_]?(\d\d)[-_]?(\d\d)[-_]?(\d\d)[-_]?(\d\d)[-_]?(\d\d)/;
    if(!all { defined } @parts) {
        warn "Unable to parse datestamp information from $name\n";
        return undef;
    }

    return timelocal($parts[5], $parts[4], $parts[3], $parts[2], $parts[1], $parts[0]);
}


## @fn $ build_times($filenames)
# Given a list of filenames, try to generate a list of hashes containing
# filenames and the corresponding DateTime object.
#
# @param filenames A reference to an array of file names.
# @return A reference to an array of hashes.
sub build_times {
    my $filenames = shift;
    my $settings  = shift;

    my @files = ();
    foreach my $file (@{$filenames}) {
        my $date = name_to_epoch($file);

        push(@files, {"name" => $file, "date" => $date})
            if($date);
    }

    return \@files;
}


## @fn $ seek_blocks($files, $settings)
# Given a list of filename, try to locate blocks of contiguous video
# based on timing.
#
# @param files
sub seek_blocks {
    my $files    = shift;
    my $settings = shift;

    # Attach timestamps to the files to allow inter-file timing to be checked.
    my $dated = build_times($files);

    # Start off with the first block being the first file.
    my $blockepoch = $dated -> [0] -> {"date"};
    my $blockname  = $dated -> [0] -> {"name"};

    my $blocks = { };
    foreach my $file (@{$dated}) {
        if(($file -> {"date"} - $blockepoch) > $settings -> {"splicer"} -> {"seq_threshold"}) {
            $blockname  = $file -> {"name"};
        }

        $blockepoch = $file -> {"date"};
        push(@{$blocks -> {$blockname}}, $file -> {"name"});
    }

    return $blocks;
}


my $settings = Webperl::ConfigMicro -> new(path_join($path, "config", "archive.cfg"))
    or die "Unable to load configuration file: ".$Webperl::SystemModule::errstr."\n";

my @files = sort(@ARGV);
my $blocks = seek_blocks(\@files, $settings);

print "Blocks: ".Dumper($blocks)."\n";
