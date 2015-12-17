#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Tiny;
use JSON::MaybeXS;
use Path::Class;
use URI;
use Carp;
use Capture::Tiny ':all';
use DateTime::Tiny;

use DDP;

# This script aims to download the modules on the perl6 master list and
# deploy them to cpan

my $scratch_dir = dir('/tmp/p6scratch');
my $dists_to_upload = $scratch_dir->subdir('to_upload');

my $module_list_source
    = 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

my $modules = _get_master_list();

my $debug = 1;

my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1, canonical => 1 );

# Don't upload if we have already done so!
my $tracker_file = file($0)->dir->file('upload_tracker.json');
my $tracker      = $json->decode( $tracker_file->slurp );

my $current_datetime = DateTime::Tiny->now->ymdhms;
$current_datetime =~ s/[-T:]//g;    # strip down to just numbers

my $version = 'v0.0.' . $current_datetime;

foreach my $module_meta ( @{$modules} ) {

    print "Fetch: $module_meta\n" if $debug;
    my $response = HTTP::Tiny->new->get($module_meta);
    if ( $response->{success} ) {

        # Fetch the meta info about the module repo
        my $meta = decode_json( $response->{content} );

        # Find where the repo is
        my $source_url = URI->new(    #
            $meta->{'source-url'} || $meta->{'support'}->{'source'}
        );

        # Create somewhere to checkit out to
        my $path      = file( $source_url->path )->dir;
        my $dist_repo = file( $source_url->path )->basename;
        $dist_repo =~ s/\.git$//;

        my $gh_author_dir = $scratch_dir->subdir($path);
        $gh_author_dir->mkpath;

        # CD into here to clone/update
        chdir $gh_author_dir->stringify;

        my $dist_dir = $gh_author_dir->subdir($dist_repo);

        # cleanup
        $dist_dir->rmtree() if -d $dist_dir;

        # clone a fresh copy
        {
            my $clone_url = $source_url->as_string;
            my $cmd       = "git clone -q ${clone_url}";
            my ( $stdout, $stderr, $exit ) = capture {
                system($cmd );
            };
            die $stderr if $stderr;
        }

        my $meta6_file = $dist_dir->file('META6.json');

        # They are probably releasing themselves
        if ( -e $meta6_file ) {
            print "- Skipping as there is a META6.json file\n" if $debug;
            next;
        }

        chdir $dist_dir->stringify;

        my $sha;
        {
            # Find out if we have already uploaded this or not
            my $cmd = 'git rev-parse master';
            my ( $current_sha, $stderr, $exit ) = capture {
                system($cmd );
            };
            die $stderr if $stderr;

            chomp($current_sha);

            # If we have uploaded it before...
            my $track_data = $tracker->{ $source_url->as_string };
            if ( my $uploaded_sha  ) {

                # This repo has not been updated, not need to update
                if ( $current_sha eq $uploaded_sha ) {
                    print "- Skipping, already uploaded this sha\n" if $debug;
                    next;
                }
            }

            $sha = $current_sha;
        }

        # Use our own time stamp based version
        $meta->{version} = $version;

        # Write out as META6.json
        $meta6_file->spew( $json->encode($meta) );

        {
            my $add_m6 = "git commit -a -m 'add META6.json'";
            my ( $stdout, $stderr, $exit ) = capture {
                system($add_m6 );
            };
            die $stderr if $stderr;
        }

        my $tar_base
            = $meta->{name} =~ s/::/-/gr . '-' . $meta->{version} =~ s/^v//r;

        my $tar_file = "../${tar_base}.tar.gz";

        {
            # Create an archive of this version
            my $cmd = 'git archive --format=tar --prefix='
                . "$tar_base/ HEAD | gzip > $tar_file";
            my ( $stdout, $stderr, $exit ) = capture {
                system($cmd );
            };
            die $stderr if $stderr;
        }
        # UPLOAD file to CPAN!

        # Track the sha that we used to upload
        $tracker->{ $source_url->as_string } = $sha;

        # Save that we've uploaded so far
        my $tra_json = $json->encode($tracker);
        p $tra_json;
        warn  "$tracker_file";
        $tracker_file->spew( $tra_json );
        warn "T";

    }
    exit;
}

print "Remember to commit the changes to upload_tracker.json\n";

sub _get_master_list {

    my $response = HTTP::Tiny->new->get($module_list_source);
    if ( $response->{success} ) {
        my @modules_meta = split( "\n", $response->{content} );
        return \@modules_meta;
    }
}
