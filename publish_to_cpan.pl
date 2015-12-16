#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Tiny;
use JSON::MaybeXS;
use Path::Class;
use URI;
use Carp;
use Capture::Tiny ':all';

use DDP;

# This script aims to download the modules on the perl6 master list and
# deploy them to cpan

my $scratch_dir = dir('/tmp/p6scratch');

my $module_list_source
    = 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

my $modules = _get_master_list();

my $debug = 1;

my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1, canonical => 1 );

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
        if ( -d $dist_dir ) {

            # do an update
            my $cmd = 'git pull --rebase --quiet';
            my ( $stdout, $stderr, $exit ) = capture {
                system($cmd );
            };

        } else {

            # clone
            my $clone_url = $source_url->as_string;
            my $cmd       = "git clone ${clone_url}";
            my ( $stdout, $stderr, $exit ) = capture {
                system($cmd );
            };

        }

        chdir $dist_dir->stringify;

        my $meta6_file = $dist_dir->file('META6.json');

        # They are probably releasing themselves
        next if -e $meta6_file;

        # Sort out a version number
        if ( $meta->{version} eq '*' || !exists $meta->{version} ) {
            $meta->{version} = '1.2.3.4.5';
        }

        # Write out
        $meta6_file->spew( $json->encode($meta) );

        my $tar_base
            = $meta->{name} =~ s/::/-/gr . '-' . $meta->{version} =~ s/^v//r;

        my $tar_file = "../${tar_base}.tar.gz";

        # Create an archive of this version
        my $cmd = 'git archive --format=tar --prefix=' . "$tar_base/ HEAD | gzip > $tar_file";
        my ( $stdout, $stderr, $exit ) = capture {
            system($cmd );
        };
        die $stderr if $stderr;

        # Cleanup after ourselves
        $meta6_file->remove();

    }
    exit;
}

sub _get_master_list {

    my $response = HTTP::Tiny->new->get($module_list_source);
    if ( $response->{success} ) {
        my @modules_meta = split( "\n", $response->{content} );
        return \@modules_meta;
    }
}
