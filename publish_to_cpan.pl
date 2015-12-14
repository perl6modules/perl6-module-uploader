#!/usr/bin/env perl

use strict;
use warnings;

use HTTP::Tiny;
use JSON::MaybeXS;

use Carp;

my $module_list_source = 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

my $modules = _get_master_list();

foreach my $module_meta (@{$modules}) {
 my $response = HTTP::Tiny->new->get($module_meta);
 if($response->{success}) {


  }
  

}


sub _get_master_list {

 my $response = HTTP::Tiny->new->get($module_list_source);
 if($response->{success}) {
   my @modules_meta = split("\n", $response->{content});
   return \@modules_meta;
  }
}
