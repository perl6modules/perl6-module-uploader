#!/bin/bash


export PATH="$HOME/.plenv/bin:$PATH"

eval "$(plenv init -)"

cd /home/perl6modules/perl6-module-uploader

RUN_GIT_PUSH=1 carton exec ./publish_to_cpan.pl

