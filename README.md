# perl6-module-uploader

### Upload the perl6 module list to CPAN

In order to help maintain Perl 6 modules/distributions availability
(e.g. if someone deletes their Github repo there will still be a copy), we
are automating the upload from http://modules.perl6.org/ to http://www.cpan.org/

### Some general points worth noting:

- If there is already a `META6.json` file in the repo then we will not
upload the distribution, as we assume the author is already doing so.
- We produce a version of `v0.0.YYYYMMDDhhmmss`, this will allow an author to add a META6.json and release their own version (we will happily transfer over any PAUSE permissions required).
- [PAUSE](https://pause.cpan.org/) now recognises Perl6 modules, by virtue of their having a META6.json file and will place these distributions in to a `/Perl6/` directory under each author ([e.g.](http://www.cpan.org/authors/id/J/JD/JDV/Perl6/)).
- [MetaCPAN](https://www.metacpan.org), [no longer](https://github.com/CPAN-API/cpan-api/commit/eaaefbf07d202b06ec6e8d9b693d1f24a5235927) indexes modules in a /Perl6/ repo. There is a project build a MetaCPAN6: [Test box server](http://hack.p6c.org:5001/) / [Test releases](http://hack.p6c.org:5001/author/JDV/releases) / [This projects releases](http://hack.p6c.org:5001/author/PSIXDISTS/releases).


You can see the distributions we have uploaded on
[https://metacpan.org/author/PSIXDISTS](https://metacpan.org/author/PSIXDISTS)
