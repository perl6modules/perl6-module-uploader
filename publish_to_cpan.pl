#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Tiny;
use CPAN::Uploader;
use JSON::MaybeXS;
use Path::Class;
use URI;
use Carp;
use Capture::Tiny ':all';
use DateTime::Tiny;
use Cwd 'abs_path';
use version;
use Gzip::Faster;

use DDP;

# This script aims to download the modules on the perl6 master list and
# deploy them to cpan

# Config (get a GENERATE TOKEN from https://github.com/settings/tokens)
# ~/.pause
# user PSIXDISTS
# password PASSWORD
# gh_token TOKEN

# If you want to git add / git commit in the 'author' dir this
# should be true
my $GIT_MANAGE_AUTHOR_DIR = 1;

# Some basic debugging messages
my $debug = 1;
my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1, canonical => 1 );

# Find out what it already uploaded to CPAN by other authors
my $on_cpan = _uploaded_to_cpan_by_other_authors();

# username / password in ~/.pause file
my $config = CPAN::Uploader->read_config_file();
$config->{subdir} = 'Perl6';
my $gh_token = delete $config->{gh_token};
my $uploader = CPAN::Uploader->new($config);

my $module_list_source
    = 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

my $modules = _get_master_list();

# Work out where we are
my $my_dir      = file( abs_path($0) )->dir;
my $authors_dir = $my_dir->parent->subdir('authors');

# Don't upload if we have already done so!
my $tracker_file    = $my_dir->file('upload_tracker.json');
my $tracker_content = $tracker_file->slurp;
my $tracker         = $json->decode($tracker_content);

# Make up a version that isn't going to limit authors later on
# but still increments
my $current_datetime = DateTime::Tiny->now->ymdhms;
$current_datetime =~ s/[-T:]//g;    # strip down to just numbers
$current_datetime =~ s/^\d{2}//;    # trim the year to 2 digets
$current_datetime =~ s/\d{2}$//;    # rm seconds - so version->parse() works
my $version = '0.000.000_' . $current_datetime;

$version = '0.000.001';

# Little sanity check
print "Version now is: " . version->parse($version) . "\n";

my $gh_http_tiny = HTTP::Tiny->new(
    default_headers => { 'Authorization' => "token $gh_token" } );

MODULE: while ( my $module_meta = shift @{$modules} ) {

    print "Checking: $module_meta\n" if $debug;
    my $response = HTTP::Tiny->new->get($module_meta);
    if ( $response->{success} ) {

        # Fetch the meta info about the module repo
        my $meta = decode_json( $response->{content} );

        # skip FROGGS test case for dups! - should fix this at some point!
        next if $meta->{name} eq 'Foo';

        if ( $on_cpan->{ $meta->{name} } ) {
            print
                "- Skipping, someone else is uploading this p6 module to CPAN\n"
                if $debug;
            next MODULE;

        }

        # Find where they want to report the repo as being
        my $source_url = URI->new(    #
            delete $meta->{'source-url'}
                || $meta->{'support'}->{'source'}
                || delete $meta->{'repo-url'}
        );

        unless ($source_url) {
            warn "Unable to fetch source_url from:";
            p $meta;
            next MODULE;
        }

        # Create somewhere to checkit out to
        my $author_path = file( $source_url->path )->dir;
        my $dist_repo   = file( $source_url->path )->basename;
        $dist_repo =~ s/\.git$//;

        my $sha;

        {    # Check if we have already done this sha
            my $repo_meta
                = sprintf
                "https://api.github.com/repos%s/%s/git/refs/heads/master",
                $author_path, $dist_repo;

            my $repo_response = $gh_http_tiny->get($repo_meta);
            if ( $repo_response->{success} ) {
                my $head = decode_json( $repo_response->{content} );
                $sha = $head->{object}->{sha};

                if ( my $track_data = $tracker->{ $meta->{name} } ) {

                    # This repo has not been updated, no need to update
                    if ( $sha eq $track_data->{sha} ) {
                        print "- Skipping, already uploaded this sha\n"
                            if $debug;
                        next MODULE;
                    }
                }

            } else {
                print "- Unable to fetch repo meta: $repo_meta\n";
                next MODULE;
            }
        }

        # All good...
        my $gh_author_dir = $authors_dir->subdir($author_path);
        $gh_author_dir->mkpath;

        # CD into here to clone/update
        chdir $gh_author_dir->stringify;

        my $dist_dir = $gh_author_dir->subdir($dist_repo);

        # cleanup
        _delete_dist_clone($dist_dir);

        # clone a fresh copy
        {
            my $clone_url = $source_url->as_string;
            my $cmd       = "git clone -q ${clone_url}";
            my ( $stdout, $stderr, $exit ) = capture {
                system($cmd );
            };
            next MODULE if $stderr;
        }

        my $meta6_file = $dist_dir->file('META6.json');

        # If there is a META6.json - use that
        if ( -e $meta6_file ) {
            my $meta6_content = $meta6_file->slurp;
            $meta = $json->decode($meta6_content);
        }

        $meta->{version_from_original_meta} = $meta->{version} || 'unknown';

        # Make sure all files conform to spec
        $meta->{'support'}->{'source'} = $source_url->as_string;

        chdir $dist_dir->stringify;

        # Use our own time stamp based version
        $meta->{version} = $version;

        # Write out as META6.json
        $meta6_file->spew( $json->encode($meta) );
        {
            my @cmds = ( "git add META6.json",
                "git commit -a -m 'add META6.json'" );

            foreach my $cmd (@cmds) {
                my ( $stdout, $stderr, $exit ) = capture {
                    system($cmd );
                };
                die $stderr if $stderr;
            }
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
        $uploader->upload_file("$tar_file");

        # Track the sha that we used to upload
        $tracker->{ $meta->{name} } = {
            sha     => $sha,
            version => $version,
            name    => $meta->{name},
            source  => $source_url->as_string,
        };

        # Save that we've uploaded so far
        my $tra_json = $json->encode($tracker);
        $tracker_file->spew($tra_json);

        # Delete repo clone as we do not need it now
        _delete_dist_clone($dist_dir);

        # Save the author repo, just for kicks, after we've deleted the clone
        my $commit_msg = sprintf 'Adding: %s version %s from %s',
            $meta->{name}, $version, $sha;
        _add_to_author_repo($commit_msg);

    }

#    exit;

}

sub _add_to_author_repo {
    my ($commit_msg) = @_;

    return unless $GIT_MANAGE_AUTHOR_DIR;

    chdir $authors_dir->stringify;

    # Add it
    {
        my $cmd = "git add .";
        my ( $stdout, $stderr, $exit ) = capture {
            system($cmd );
        };
        die $stderr if $stderr;
    }

    # Check it in
    {
        my $cmd = "git cia -m'$commit_msg'";
        my ( $stdout, $stderr, $exit ) = capture {
            system($cmd );
        };
        die $stderr if $stderr;
    }

}

print "Remember to commit the changes to upload_tracker.json\n";

sub _delete_dist_clone {
    my $dist_dir = shift;
    return unless -d $dist_dir;

    chdir $authors_dir->stringify;
    $dist_dir->rmtree();
}

# See what is uploaded by other authors as we don't
# want to upload a module if someone else is doing it
sub _uploaded_to_cpan_by_other_authors {

    my $p6dists = 'http://www.cpan.org/authors/p6dists.json.gz';

    my $response = HTTP::Tiny->new->get($p6dists);

    if ( $response->{success} ) {
        my $compressed = $response->{content};

        my $output  = gunzip($compressed);
        my $decoded = $json->decode($output);

        my %on_cpan;
        foreach my $key ( keys %{$decoded} ) {
            my $module_meta = $decoded->{$key};

            # Don't count our own uploads
            next if $module_meta->{auth} eq 'PSIXDISTS';
            $on_cpan{ $module_meta->{name} } = 1;
        }

        return \%on_cpan;
    } else {
        die "Unable to fetch $p6dists fix then proceed";
    }
}

sub _get_master_list {

    my $response = HTTP::Tiny->new->get($module_list_source);
    if ( $response->{success} ) {
        my @modules_meta = grep { $_ =~ /META.info/ }
            split( "\n", $response->{content} );
        return \@modules_meta;
    }
}
