use inc::Module::Install;

name('Kwiki-Archive-SVK');
author('Autrijus Tang <autrijus@autrijus.org>');
abstract('Kwiki Page Archival Using SVK');
license('perl');
version_from('lib/Kwiki/Archive/SVK.pm');

requires(qw(
    perl 5.6.1
    Kwiki 0.33
));

&WriteAll;
