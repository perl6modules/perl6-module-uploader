#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Tiny;
use JSON::MaybeXS;
use Path::Class;
use URI;
use Carp;
use IPC::Run3;

use DDP;

# This script aims to download the modules on the perl6 master list and
# deploy them to cpan

my $scratch_dir = dir('/tmp/p6scratch');

my $module_list_source
    = 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

my $modules = _get_master_list();

my $debug = 1;

foreach my $module_meta ( @{$modules} ) {

    print "Fetch: $module_meta\n" if $debug;
    my $response = HTTP::Tiny->new->get($module_meta);
    if ( $response->{success} ) {

        # Fetch the meta info about the module repo
        my $meta = decode_json( $response->{content} );

        # Create somewhere to download it to
        my $url        = URI->new( $meta->{'source-url'} );
        my $path       = file( $url->path )->dir;
        my $author_dir = $scratch_dir->subdir($path);
        $author_dir->mkpath;

        p $author_dir->stringify;
    }

}

sub _get_master_list {

    my $response = HTTP::Tiny->new->get($module_list_source);
    if ( $response->{success} ) {
        my @modules_meta = split( "\n", $response->{content} );
        return \@modules_meta;
    }
}
