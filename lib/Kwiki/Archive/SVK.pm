package Kwiki::Archive::SVK;
use strict;
use warnings;
use SVK;
use SVK::XD;
use SVN::Repos;
use Kwiki::Archive '-Base';
our $VERSION = '0.01';

sub register {
    super;
    my $registry = shift;
    $registry->add(page_hook_content => 'page_content');
    $registry->add(page_hook_metadata => 'page_metadata');
    $registry->add(attachments_hook_list => 'attachments_list');
    $registry->add(attachments_hook_upload => 'attachments_upload');
    $registry->add(attachments_hook_delete => 'attachments_delete');
}

sub generate {
    super;
    SVN::Repos::create(
        $self->plugin_directory, undef, undef, undef, {
            ($SVN::Core::VERSION =~ /^1\.0/) ? (
                'bdb-txn-nosync' => '1',
                'bdb-log-autoremove' => '1',
            ) : (
                'fs-type' => 'fsfs',
            )
        }
    );
}

sub attachments_upload {
    my ($attachments, $page_id, $file, $message) = @_;
    my ($svk, $out) = $self->svk($attachments);
    my $co_file = io->catfile(
        io->rel2abs($attachments->plugin_directory), $page_id, $file
    )->name;
    $svk->mkdir(-m => "", "//attachments/$page_id");
    $svk->add($co_file);
    $svk->commit(-m => "$message", $co_file);
}

sub attachments_list {
    my ($attachments, $page_id) = @_;
    my ($svk, $out) = $self->svk($attachments);
    $svk->list("//attachments/$page_id");
    foreach my $file (split(/\n/, $$out)) {
        $svk->revert(
            io->catfile(
                io->rel2abs($attachments->plugin_directory), $page_id, $file
            )->name
        );
    }
}

sub attachments_delete {
    my ($attachments, $page_id, $file, $message) = @_;
    my ($svk, $out) = $self->svk($attachments);
    my $co_file = io->catfile(
        io->rel2abs($attachments->plugin_directory), $page_id, $file
    )->name;
    $svk->delete($co_file);
    $svk->commit(-m => "$message", $co_file);
}

sub page_content {
    my $page = shift;
    my ($svk, $out) = $self->svk($page);
    my $co_file = $page->io->rel2abs;

    my ($atime, $mtime) = (stat $co_file)[8, 9];
    $svk->revert($co_file);
    utime($atime, $mtime, $co_file);
}

sub page_metadata {
    my $page = shift;
    my ($svk, $out) = $self->svk($page);
    my $co_file = $page->io->rel2abs;
    my $metadata = $page->{metadata};

    $svk->proplist($co_file); utf8::decode($$out);
    $metadata->from_hash({ $$out =~ /^kwiki:(\w+): (.+)$/mg });
    $metadata->store;
}

sub commit {
    my $page = shift;
    my $message = shift;
    my ($svk, $out) = $self->svk($page);
    my $co_file = $page->io->rel2abs;
    my $props = $self->page_properties($page);

    $svk->add($co_file);
    $svk->propset("kwiki:$_" => $props->{$_}, $co_file)
      foreach sort keys %$props;
    $svk->commit(-m => "$message", $co_file);
}

sub history {
    my $page = shift;
    my ($svk, $out) = $self->svk($page);
    my $co_file = $page->io->rel2abs;
    $svk->log($co_file); utf8::decode($$out);

    return [map {
        my ($rev, $msg) = /r(\d+):.*\n\n([\d\D]*)/;
        $rev ? do {
            $svk->proplist(-r => $rev, $co_file);
            +{
                $$out =~ /^kwiki:(\w+): (.+)$/mg,
                message => $msg,
                revision_id => $rev,
            };
        } : ();
    } split /^-+\n/m, $$out];
}

sub fetch {
    my $page = shift;
    my $revision_id = shift;
    my ($svk, $out) = $self->svk($page);

    $svk->cat(-r => $revision_id, $page->io->rel2abs);
    $self->utf8_decode($$out);
}

sub svk {
    my $obj = shift;
    my $co = Data::Hierarchy->new;
    my $xd = SVK::XD->new(
        depotmap => { '' => io->rel2abs($self->plugin_directory) },
        checkout => $co,
        svkpath => io->rel2abs($self->plugin_directory),
    );

    my $output;
    my $repos = ($xd->find_repos('//', 1))[2];
    my $svk = SVK->new(xd => $xd, output => \$output);

    if ($obj->class_id eq 'page') {
        $co->store(
            io->rel2abs($obj->database_directory),
            { depotpath => '//pages', revision => $repos->fs->youngest_rev },
        );
        $svk->mkdir(-m => "", "//pages");
    }
    elsif ($obj->class_id eq 'attachments') {
        $co->store(
            io->rel2abs($obj->plugin_directory),
            { depotpath => '//attachments', revision => $repos->fs->youngest_rev },
        );
        $svk->mkdir(-m => "", "//attachments");
    }

    return wantarray ? ($svk, \$output) : $svk;
}

1;

__DATA__

=head1 NAME 

Kwiki::Archive::SVK - Kwiki Page Archival Using SVK

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Autrijus Tang <autrijus@autrijus.org>

=head1 COPYRIGHT

Copyright 2004.  Autrijus Tang.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
