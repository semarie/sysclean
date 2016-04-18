#!/usr/bin/perl
#
# $OpenBSD$
#
# Copyright (c) 2016 Sebastien Marie <semarie@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

use strict;
use warnings;

package sysclean;

# return subclass according to options
sub subclass
{
	my ($self, $options) = @_;
	return 'sysclean::packages' if (defined $$options{p});
	return 'sysclean::allfiles' if (defined $$options{a});
	return 'sysclean::files'    if (defined $$options{f});
}

# choose class for mode, depending on %options
sub create
{
	my ($base, $options) = @_;

	my $with_ignored = !defined $$options{i};

	sysclean->usage if ((!defined $$options{f} && !defined $$options{p}) ||
	    (defined $$options{f} && defined $$options{p}) ||
	    (defined $$options{p} && defined $$options{a}));

	return $base->subclass($options)->new($with_ignored);
}

# constructor
sub new
{
	my ($class, $with_ignored) = @_;
	my $self = bless {}, $class;

	$self->init_ignored;
	$self->init;
	$self->add_user_ignored if ($with_ignored);

	return $self;
}

# print usage and exit
sub usage
{
	print "usage: $0 -f [-ai]\n";
	print "       $0 -p [-i]\n";
	exit 1
}

# print error and exit
sub err
{
	my ($self, $exitcode, @rest) = @_;

	print STDERR "$0: error: @rest\n";

	exit $exitcode;
}

# initial list of ignored files and directories
sub init_ignored
{
	my $self = shift;

	$self->{ignored} = {
		'/dev' => 1,
		'/home' => 1,
		'/root' => 1,
                '/tmp' => 1,
		'/usr/local' => 1, # remove ?
		'/usr/obj' => 1,
		'/usr/ports' => 1,
		'/usr/src' => 1,
		'/usr/xenocara' => 1,
                '/usr/xobj' => 1,
		'/var/backups' => 1,
		'/var/cache' => 1,
		'/var/cron' => 1,
		'/var/db' => 1,
		'/var/log' => 1,
                '/var/mail' => 1,
		'/var/run' => 1,
		'/var/spool/smtpd' => 1,
		'/var/sysmerge' => 1,
                '/var/www/htdocs' => 1,
		'/var/www/logs' => 1,
		'/var/www/run' => 1,
		'/var/www/tmp' => 1,
	};
}

sub init
{
	my ($self) = @_;

	$self->add_expected_base;
	$self->add_expected_ports_info;
}

# add expected files from base
# WARNING: `expected' attribute is overrided
sub add_expected_base
{
	my $self = shift;

	# simple files expected (and not in locate databases)
	$self->{expected} = {
		'/' => 1,
		'/boot' => 1,
		'/bsd' => 1,
		'/bsd.mp' => 1,
		'/bsd.rd' => 1,
		'/bsd.sp' => 1,
		'/obsd' => 1,
		'/etc/fstab' => 1,
		'/etc/hosts' => 1,
		'/etc/iked/local.pub' => 1,
		'/etc/iked/private/local.key' => 1,
		'/etc/isakmpd/local.pub' => 1,
		'/etc/isakmpd/private/local.key' => 1,
		'/etc/ssh/ssh_host_rsa_key' => 1,
		'/etc/ssh/ssh_host_rsa_key.pub' => 1,
		'/etc/ssh/ssh_host_dsa_key' => 1,
		'/etc/ssh/ssh_host_dsa_key.pub' => 1,
		'/etc/ssh/ssh_host_ecdsa_key' => 1,
		'/etc/ssh/ssh_host_ecdsa_key.pub' => 1,
		'/etc/ssh/ssh_host_ed25519_key' => 1,
		'/etc/ssh/ssh_host_ed25519_key.pub' => 1,
		'/etc/myname' => 1,
		'/etc/pkg.conf' => 1,
		'/etc/random.seed' => 1,
	};

	use OpenBSD::Paths;

	open(my $cmd, '-|', 'locate',
		'-d', OpenBSD::Paths->srclocatedb,
		'-d', OpenBSD::Paths->xlocatedb,
		'*') || $self->err(1, "can't read base locatedb");
	while (<$cmd>) {
		chomp;
		my ($set, $path) = split(':', $_, 2);
		$self->{expected}{$path} = 1;
	}
	close($cmd);
}

# add expected information from ports. the method will call `plist_reader'
# overriden method.
sub add_expected_ports_info
{
	my $self = shift;

	use OpenBSD::PackageInfo;
	use OpenBSD::PackingList;

	for my $pkgname (installed_packages()) {
		my $plist = OpenBSD::PackingList->from_installation($pkgname,
		    $self->plist_reader);
		$plist->walk_sysclean($pkgname, $self);
	}
}

# add user-defined `ignored' files
sub add_user_ignored
{
	my $self = shift;

	open(my $fh, "<", "/etc/sysclean.ignore") || return;
	while (<$fh>) {
		chomp;
		$self->{ignored}{$_} = 1;
	}
	close($fh);
}

# walk the filesystem. the method will call `findsub' overriden method.
sub walk
{
	my $self = shift;

	use File::Find;

	find({ wanted =>
	    sub {
		if (exists($self->{ignored}{$_})) {
			# skip ignored files
			$File::Find::prune = 1;

		} elsif (! exists($self->{expected}{$_})) {
			# not expected file

			if ( -d $_ ) {
				# don't descend in unknown directory
				$File::Find::prune = 1;
			}

			# findsub is defined per mode
			$self->findsub($_);
		}
	    }, follow => 0, no_chdir => 1, }, '/');
}


#
# specialized versions
#

package sysclean::allfiles;
use parent -norequire, qw(sysclean);

sub plist_reader
{
	return sub {
	    my ($fh, $cont) = @_;
	    while (<$fh>) {
		    next unless m/^\@(?:cwd|name|info|man|file|lib|shell|extra|sample|bin|rcscript)\b/o || !m/^\@/o;
		    &$cont($_);
	    };
	}
}

sub findsub
{
	my ($self, $filename) = @_;

	print($filename, "\n");
}

package sysclean::files;
use parent -norequire, qw(sysclean);

sub plist_reader
{
	return sub {
	    my ($fh, $cont) = @_;
	    while (<$fh>) {
		    next unless m/^\@(?:cwd|name|info|man|file|lib|shell|extra|sample|bin|rcscript|wantlib)\b/o || !m/^\@/o;
		    &$cont($_);
	    };
	}
}

sub findsub
{
	my ($self, $filename) = @_;

	if ($filename =~ m|/lib([^/]*)\.so(\.[0-9.]*)$|o &&
	    exists($self->{used_libs}{"$1$2"})) {

		# skip used-libs
		return;
	}

	print($filename, "\n");
}

package sysclean::packages;
use parent -norequire, qw(sysclean);

sub plist_reader
{
	return \&OpenBSD::PackingList::DependOnly;
}

sub findsub
{
	my ($self, $filename) = @_;

	if ($filename =~ m|/lib([^/]*)\.so(\.[0-9.]*)$|o) {
		my $wantlib = "$1$2";

		print($filename, "\t", $self->{used_libs}{$wantlib}, "\n")
			if (exists($self->{used_libs}{$wantlib}));
	}
}


#
# extent OpenBSD::PackingElement for walking
#

package OpenBSD::PackingElement;
sub walk_sysclean
{
}

package OpenBSD::PackingElement::FileObject;
sub walk_sysclean
{
	my ($item, $pkgname, $sc) = @_;

	$sc->{expected}{$item->fullname} = 1;
}

package OpenBSD::PackingElement::Sampledir;
sub walk_sysclean
{
	my ($item, $pkgname, $sc) = @_;

	$sc->{ignored}{$item->fullname} = 1;
}

package OpenBSD::PackingElement::Wantlib;
sub walk_sysclean
{
	my ($item, $pkgname, $sc) = @_;

	$sc->{used_libs}{$item->name} = $pkgname;
}


#
# main program
#
package main;

use Getopt::Std;

my %options = ();	# program flags

getopts("fpaih", \%options) || sysclean->usage;
sysclean->usage if (defined $options{h} || scalar(@ARGV) != 0);

print STDERR "warn: need root privileges for complete listing\n" if ($> != 0);

my $sc = sysclean->create(\%options);
$sc->walk;
