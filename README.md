# PROJECT DEPRECIATED

Perl 6 authors are now uploading to PAUSE/CPAN directly themselves, that makes this project redundunt *CHEER*!!!!

# NOW OUT OF DATE...

### Upload the perl6 module list to CPAN

In order to help maintain Perl 6 modules/distributions availability
(e.g. if someone deletes their Github repo there will still be a copy), we
are automating the upload from http://modules.perl6.org/ to http://www.cpan.org/

### Some general points worth noting:

- [PAUSE](https://pause.cpan.org/) now recognises Perl6 modules, by virtue of their being uploaded to a `Perl6` subdir and having a META6.json file ([read instructions](https://pause.perl.org/pause/authenquery?ACTION=add_uri)) you can then see them under the author ([e.g.](http://www.cpan.org/authors/id/J/JD/JDV/Perl6/)).
- We check [http://www.cpan.org/authors/p6dists.json.gz](http://www.cpan.org/authors/p6dists.json.gz) to make sure that no one is already uploading a Perl6 module of this name to CPAN, and we will automatically stop if someone does  in future. We can't be sure it is the same author as ours ([Perl 6 allows modules of the same name](http://irclog.perlgeek.de/perl6/2015-12-21#i_11754649) but different authors), but we don't have a better way to check at the moment.
- We produce a version of `0.000.00X_YYMMDD` for each release, this will allow an author to release their own version numbering scheme.
- [MetaCPAN](https://www.metacpan.org), [no longer](https://github.com/CPAN-API/cpan-api/commit/eaaefbf07d202b06ec6e8d9b693d1f24a5235927) indexes modules in a /Perl6/ subdir. There is a project to build a MetaCPAN6: [Test box server](http://hack.p6c.org:5001/) / [Test releases](http://hack.p6c.org:5001/author/JDV/releases) / [This projects releases](http://hack.p6c.org:5001/author/PSIXDISTS/releases) which will index Perl6 distributions.

You can see the distributions we have uploaded on
[http://www.cpan.org/authors/id/P/PS/PSIXDISTS/Perl6/](http://www.cpan.org/authors/id/P/PS/PSIXDISTS/Perl6/)
