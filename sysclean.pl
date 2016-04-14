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

# extent OpenBSD::PackingElement for walking though FileObject
package OpenBSD::PackingElement;
sub walk_sysclean
{
}

package OpenBSD::PackingElement::FileObject;

sub walk_sysclean
{
	my $item = shift;
	my $pkgname = shift;
	my $expected = shift;
	my $used_libs = shift;

	my $fname = $item->fullname;
	# no filter (but mem usage)				# 26.81 27.84 27.99
	#return if ($fname =~ m|^/usr/local/|o);		# 26.83 27.67 27.98
	#return if (index($fname, '/usr/local/') == 0);		# 25.53 27.44 27.70
	#return if (substr($fname, 0, 11) eq '/usr/local/');	# 26.53 26.93 27.64

	$$expected{$fname} = 1;
}

package OpenBSD::PackingElement::Wantlib;
sub walk_sysclean
{
	my $item = shift;
	my $pkgname = shift;
	my $expected = shift;
	my $used_libs = shift;

	$$used_libs{$item->name} = $pkgname;
}

# go back to real program
package main;

use Getopt::Std;

my %options = ();	# program flags
my %ignored = ();	# user-ignored files

sub sc_usage
{
	print "usage: $0 -f [-ai]\n";
	print "       $0 -p [-i]\n";
	exit 1
}

sub sc_err
{
	my $exitcode = shift;

	print "$0: error: @_\n";

	exit $exitcode;
}

sub sc_generate_expected_base
{
	use OpenBSD::Paths;

	my $expected = shift;

	# base system	
	open(my $cmd, '-|', 'locate',
		'-d', OpenBSD::Paths->srclocatedb,
		'-d', OpenBSD::Paths->xlocatedb,
		'*') || sc_err(1, "can't read base locatedb");
	while (<$cmd>) {
		chomp;
		my ($set, $path) = split(':', $_, 2);
		$$expected{$path} = 1;
	}
	close($cmd);

	# others files expected too
	$$expected{'/'} = 1;
	$$expected{'/boot'} = 1;
	$$expected{'/bsd'} = 1;
	$$expected{'/bsd.mp'} = 1;
	$$expected{'/bsd.rd'} = 1;
	$$expected{'/bsd.sp'} = 1;
	$$expected{'/obsd'} = 1;
	$$expected{'/etc/fstab'} = 1;
	$$expected{'/etc/hosts'} = 1;
	$$expected{'/etc/iked/local.pub'} = 1;
	$$expected{'/etc/iked/private/local.key'} = 1;
	$$expected{'/etc/isakmpd/local.pub'} = 1;
	$$expected{'/etc/isakmpd/private/local.key'} = 1;
	$$expected{'/etc/ssh/ssh_host_rsa_key'} = 1;
	$$expected{'/etc/ssh/ssh_host_rsa_key.pub'} = 1;
	$$expected{'/etc/ssh/ssh_host_dsa_key'} = 1;
	$$expected{'/etc/ssh/ssh_host_dsa_key.pub'} = 1;
	$$expected{'/etc/ssh/ssh_host_ecdsa_key'} = 1;
	$$expected{'/etc/ssh/ssh_host_ecdsa_key.pub'} = 1;
	$$expected{'/etc/ssh/ssh_host_ed25519_key'} = 1;
	$$expected{'/etc/ssh/ssh_host_ed25519_key.pub'} = 1;
	$$expected{'/etc/myname'} = 1;
	$$expected{'/etc/pkg.conf'} = 1;
	$$expected{'/etc/random.seed'} = 1;
}

sub sc_generate_expected_ports
{
	use OpenBSD::PackageInfo;
	use OpenBSD::PackingList;

	my $expected = shift;
	my $used_libs = shift;

	for my $pkgname (installed_packages()) {
		my $plist = OpenBSD::PackingList->from_installation($pkgname);
		$plist->walk_sysclean($pkgname, $expected, $used_libs);
	}
}

sub sc_generate_expected
{
	my $expected = shift;
	my $used_libs = shift;

	sc_generate_expected_base($expected);
	sc_generate_expected_ports($expected, $used_libs);
}

sub sc_print_addedfiles
{
	use File::Find;

	my %expected = ();
	my %used_libs = ();
	my %discard = (
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
	);

	sc_generate_expected(\%expected, \%used_libs);

	# -fa [-i]
	my $mode_files_all = sub
	{
		if (exists($discard{$_}) || exists($ignored{$_})) {
			# skip discard or ignored files
			$File::Find::prune = 1;

		} elsif (! exists($expected{$_})) {
			# not expected file

			if ( -d ) {
				# don't descend in unknown directory
				$File::Find::prune = 1;
			}

			print($_, "\n");
		}
	};

	# -f [-i]
	my $mode_files = sub
	{
		if (exists($discard{$_}) || exists($ignored{$_})) {
			# skip discard or ignored files
			$File::Find::prune = 1;

		} elsif (! exists($expected{$_})) {
			# not expected file

			if ( -d ) {
				# don't descend in unknown directory
				$File::Find::prune = 1;
			}

			if (m|/lib([^/]*)\.so(\.[0-9.]*)$|o &&
				exists($used_libs{"$1$2"})) {
				
				# skip used-libs
				return;
			}
	
			print($_, "\n");
		}
	};

	# -p [-i]
	my $mode_packages = sub
	{
		if (exists($discard{$_}) || exists($ignored{$_})) {
			# skip discard or ignored files
			$File::Find::prune = 1;

		} elsif (! exists($expected{$_})) {
			# not expected file

			if ( -d ) {
				# don't descend in unknown directory
				$File::Find::prune = 1;
			}

			my $file = $_;

			if (m|/lib([^/]*)\.so(\.[0-9.]*)$|o) {
				my $wantlib = "$1$2";

				print($file, "\t", $used_libs{$wantlib}, "\n")
					if (exists($used_libs{$wantlib}));
			}
		}
	};

	if (defined $options{f}) {
		if (defined $options{a}) {
			find({ wanted => $mode_files_all, follow => 0,
					no_chdir => 1 }, '/');
		} else {
			find({ wanted => $mode_files, follow => 0,
					no_chdir => 1 }, '/');
		}
	} else {
		find({ wanted => $mode_packages, follow => 0, no_chdir => 1 },
			'/');
	}
}

sub sc_read_ignored
{
	open(my $fh, "/etc/sysclean.ignore") || return;

	while (<$fh>) {
		chomp;
		$ignored{$_} = 1;
	}
	close($fh);
}

getopts("fpaih", \%options) || sc_usage;
sc_usage
	if ((defined $options{h}) ||
		(scalar(@ARGV) != 0) ||
		(!defined $options{f} && !defined $options{p}) ||
		(defined $options{f} && defined $options{p}) ||
		(defined $options{p} && defined $options{a}));

sc_read_ignored() if (!defined $options{i});
sc_print_addedfiles();
