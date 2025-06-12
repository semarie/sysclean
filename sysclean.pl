#!/usr/bin/perl
#
# $OpenBSD$
#
# Copyright (c) 2016-2025 Sebastien Marie <semarie@kapouay.eu.org>
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

use v5.36;

package sysclean;

# return subclass according to options
sub subclass($self, $options)
{
	return 'sysclean::allfiles' if (defined $$options{a});
	return 'sysclean::packages' if (defined $$options{p});
	return 'sysclean::files';
}

# choose class for mode, depending on %options
sub create($base, $options)
{
	my $with_ignored = !defined $$options{i};
	my $mode_count = 0;

	$mode_count++ if (defined $$options{a});
	$mode_count++ if (defined $$options{p});
	sysclean->usage if ($mode_count > 1);

	return $base->subclass($options)->new($with_ignored);
}

# constructor
sub new($class, $with_ignored)
{
	my $self = bless {}, $class;

	$self->init_ignored;
	$self->init;
	if ($with_ignored) {
		$self->add_user_ignored("/etc/changelist");
		$self->add_user_ignored("/etc/sysclean.ignore");
		$self->{expected}{'/etc/sysclean.ignore'} = 1;
	}

	return $self;
}

# print usage and exit
sub usage($self)
{
	print "usage: $0 [ -a | -p ] [-i]\n";
	exit 1
}

# print error and exit
sub err($self, $exitcode, @rest)
{
	print STDERR "$0: error: @rest\n";

	exit $exitcode;
}

# print warning
sub warn($self, @rest)
{
	print STDERR "$0: warn: @rest\n";
}

# initial list of ignored files and directories
sub init_ignored($self)
{
	$self->{ignored} = {
		'/home' => 1,
		'/root' => 1,
		'/tmp' => 1,
		'/usr/local' => 1, # remove ?
		'/usr/obj' => 1,
		'/usr/ports' => 1,
		'/usr/share/relink/kernel' => 1,
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
		'/var/syspatch' => 1,
		'/var/www/htdocs' => 1,
		'/var/www/logs' => 1,
		'/var/www/run' => 1,
		'/var/www/tmp' => 1,
	};

	# additionnal ignored files, using pattern
	foreach my $filename (</bsd.syspatch*>) {
		$self->{ignored}{$filename} = 1;
	}
}

sub init($self)
{
	use OpenBSD::PackageInfo;
	use OpenBSD::Pledge;
	use OpenBSD::Unveil;

	lock_db(1);

	unveil('/', 'r');
	unveil('/dev/MAKEDEV', 'rx');
	unveil('/usr/bin/locate', 'rx');
	unveil('/usr/sbin/rcctl', 'rx');

	pledge('rpath getpw proc exec') || $self->err(1, "pledge");
	$self->add_expected_base;
	$self->add_expected_dev;
	$self->add_expected_rcctl;

	pledge('rpath getpw') || $self->err(1, "pledge");
	$self->add_expected_users;
	$self->add_expected_ports_info;
}

# add expected files from base. call `add_expected_base_one' overriden method.
# WARNING: `expected' attribute is overrided
sub add_expected_base($self)
{
	# simple files expected (and not in locate databases)
	$self->{expected} = {
		'/' => 1,
		'/boot' => 1,
		'/ofwboot' => 1,
		'/bsd' => 1,
		'/bsd.booted' => 1,
		'/bsd.mp' => 1,
		'/bsd.rd' => 1,
		'/bsd.sp' => 1,
		'/obsd' => 1,
		'/etc/acme/letsencrypt-privkey.pem' => 1,
		'/etc/acme/letsencrypt-staging-privkey.pem' => 1,
		'/etc/fstab' => 1,
		'/etc/hosts' => 1,
		'/etc/installurl' => 1,
		'/etc/iked/local.pub' => 1,
		'/etc/iked/private/local.key' => 1,
		'/etc/isakmpd/local.pub' => 1,
		'/etc/isakmpd/private/local.key' => 1,
		'/etc/kbdtype' => 1,
		'/etc/ssh/ssh_host_rsa_key' => 1,
		'/etc/ssh/ssh_host_rsa_key.pub' => 1,
		'/etc/ssh/ssh_host_ecdsa_key' => 1,
		'/etc/ssh/ssh_host_ecdsa_key.pub' => 1,
		'/etc/ssh/ssh_host_ed25519_key' => 1,
		'/etc/ssh/ssh_host_ed25519_key.pub' => 1,
		'/etc/myname' => 1,
		'/etc/random.seed' => 1,
		'/usr/libexec/ld.so.save' => 1,
		'/var/account/acct' => 1,
		'/var/account/acct.0' => 1,
		'/var/account/acct.1' => 1,
		'/var/account/acct.2' => 1,
		'/var/account/acct.3' => 1,
		'/var/account/savacct' => 1,
		'/var/account/usracct' => 1,
	};

	# additionnal expected files, using pattern
	foreach my $filename (</etc/hostname.*>) {
		$self->{expected}{$filename} = 1;
	}

	# expected files, from locate databases
	use OpenBSD::Paths;

	open(my $cmd, '-|', 'locate',
		'-d', OpenBSD::Paths->srclocatedb,
		'-d', OpenBSD::Paths->xlocatedb,
		'*') || $self->err(1, "can't read base locatedb");
	while (<$cmd>) {
		chomp;
		my ($set, $filename) = split(':', $_, 2);
		$self->add_expected_base_one($filename);
	}
	close($cmd);
}

# default method for manipulated one expected filename of base.
sub add_expected_base_one($self, $filename)
{
	$self->{expected}{$filename} = 1;
}

# add expected files from /dev
sub add_expected_dev($self)
{
	# set 'eo=echo' in env, to run MAKEDEV(8) in echo mode.
	$ENV{'eo'} = 'echo';

	chdir('/dev') ||
		$self->err(1, "can't chdir to /dev");
	open(my $dev, '-|', './MAKEDEV', 'all') ||
		$self->err(1, "can't execute /dev/MAKEDEV");

	while (<$dev>) {
		chomp;

		# simplify command separator
		s/\s*(;|&&|\|\|)\s*/;/g;

		# iterate on commands
		foreach my $commandline (split(/;/)) {
			# split $commandline in words
			my @args = split(/\s/, $commandline);
			my $cmd = shift(@args);

			# skip commands
			next if ($cmd eq 'rm');
			next if ($cmd eq 'chown');
			next if ($cmd eq 'chgrp');
			next if ($cmd eq 'chmod');
			next if ($cmd eq '[');

			if ($cmd eq 'mkdir') {
				shift(@args); # skip -p

				foreach my $dir (@args) {
					$self->{expected}{"/dev/$dir"} = 1;
				}

			} elsif ($cmd eq 'ln') {
				my ($option, $src, $dest) = @args;
				$self->{expected}{"/dev/$dest"} = 1;

			} elsif ($cmd eq 'mknod') {
				foreach my $arg (@args) {
					if ($arg eq '-m') {
						shift(@args); # mode
						next;
					}

					$self->{expected}{"/dev/$arg"} = 1;
					shift(@args); # b|c
					shift(@args); # major
					shift(@args); # minor
				}

			} else {
				$self->err(1, "unexpected command '$cmd' in MAKEDEV output");
			}
		}
	}
	close($dev);
}

# add expected files from enabled daemons and services.
sub add_expected_rcctl($self)
{
	open(my $cmd, '-|', 'rcctl', 'ls', 'on') ||
		$self->err(1, "can't read enabled daemons and services");
	while (<$cmd>) {
		chomp;
		if ('apmd' eq $_) {
			$self->{expected}{'/etc/apm'} = 1;
			$self->{expected}{'/etc/apm/suspend'} = 1;
			$self->{expected}{'/etc/apm/hibernate'} = 1;
			$self->{expected}{'/etc/apm/standby'} = 1;
			$self->{expected}{'/etc/apm/resume'} = 1;
			$self->{expected}{'/etc/apm/powerup'} = 1;
			$self->{expected}{'/etc/apm/powerdown'} = 1;

		} elsif ('dhcp6leased' eq $_) {
			$self->{expected}{'/dev/dhcp6leased.lock'} = 1;
			$self->{expected}{'/dev/dhcp6leased.sock'} = 1;

		} elsif ('dhcpleased' eq $_) {
			$self->{expected}{'/dev/dhcpleased.lock'} = 1;
			$self->{expected}{'/dev/dhcpleased.sock'} = 1;

		} elsif ('hotplugd' eq $_) {
			$self->{expected}{'/etc/hotplug/attach'} = 1;
			$self->{expected}{'/etc/hotplug/detach'} = 1;

		} elsif ('iked' eq $_) {
			$self->{ignored}{'/etc/iked/pubkeys'} = 1;

		} elsif ('isakmpd' eq $_) {
			$self->{ignored}{'/etc/isakmpd/pubkeys'} = 1;

		} elsif ('lpd' eq $_) {
			$self->{expected}{'/etc/printcap'} = 1;
			$self->{ignored}{'/var/spool/output/lpd'} = 1;

		} elsif ('nsd' eq $_) {
			$self->{ignored}{'/var/nsd/run'} = 1;
			$self->{ignored}{'/var/nsd/zones'} = 1;

		} elsif ('resolvd' eq $_) {
			$self->{expected}{'/dev/resolvd.lock'} = 1;

		} elsif ('slaacd' eq $_) {
			$self->{expected}{'/dev/slaacd.lock'} = 1;
			$self->{expected}{'/dev/slaacd.sock'} = 1;

		} elsif ('syslogd' eq $_) {
			$self->{expected}{'/dev/log'} = 1;

		} elsif ('smtpd' eq $_) {
			$self->{expected}{'/etc/mail/aliases.db'} = 1;

		} elsif ('unbound' eq $_) {
			$self->{expected}{'/var/unbound/db/root.key'} = 1;

		} elsif ('unwind' eq $_) {
			$self->{expected}{'/dev/unwind.sock'} = 1;
			$self->{expected}{'/etc/unwind/trustanchor/root.key'} = 1;

		} elsif ('xenodm' eq $_) {
			$self->{ignored}{'/etc/X11/xenodm/authdir'} = 1;
		}
	}
	close($cmd);
}

# add expected information for users/groups.
sub add_expected_users($self)
{
	use Archive::Tar;

	my $tar = Archive::Tar->new();
	$tar->read(
	    '/var/sysmerge/etc.tgz', {
		limit => 2,
		filter => './etc/{master.passwd,group}',
	    }) || $self->err(1, "can't read /var/sysmerge/etc.tgz");

	# add groups (and keep track of gid -> gname association)
	my %groups = ();
	my $group = $tar->get_content('./etc/group');
	foreach my $entry (split(/\n/, $group)) {
		my ($name, $passwd, $gid, $members) = split(/:/, $entry);
		my $group = join(':', ($name, $gid));

		$groups{$gid} = $name;
		$self->{groups}{$group} = 1;
	}

	# add users
	my $passwd = $tar->get_content('./etc/master.passwd');
	foreach my $entry (split(/\n/, $passwd)) {
		my ($name, $passwd, $uid, $gid, $class, $change, $expire,
		    $gecos, $home, $shell) = split(/:/, $entry);
	    	my $gname = $groups{$gid} ||
	    	    $self->err(1, "unknown gid $gid in passwd '$name' entry");

		my $user = join(':', ($name, $uid, $gname, $class, $home, $shell));
		$self->{users}{$user} = 1;

		my $short = join(':', ($name, $uid));
		$self->{users}{$short} = 1;
	}

}

# add expected information from ports. the method will call `plist_reader'
# overriden method.
sub add_expected_ports_info($self)
{
	use OpenBSD::PackageInfo;
	use OpenBSD::PackingList;

	for my $pkgname (installed_packages()) {
		my $plist = OpenBSD::PackingList->from_installation($pkgname,
		    $self->plist_reader);
		$plist->walk_sysclean($pkgname, $self);
	}
}

# default plist_reader sub. could be overrided.
sub plist_reader($self)
{
	return sub ($fh, $cont) {
	    while (<$fh>) {
		    next unless m/^\@(?:cwd|name|info|fontdir|man|mandir|file|lib|shell|so|static-lib|extra|sample|bin|rcscript|wantlib|newuser|newgroup)\b/o || !m/^\@/o;
		    &$cont($_);
	    };
	}
}

# add user-defined `ignored' elements
sub add_user_ignored($self, $conffile)
{
	open(my $fh, "<", $conffile) || return 0;
	while (<$fh>) {
		chomp;

		# strip starting '+' (compat with changelist(5) format)
		s/^\+//;

		# strip comments
		s/\s*#.*$//;
		next if (m/^$/o);

		if (m/^\@include\s+"(.*)"\s*$/) {
			# include another conffile
			$self->add_user_ignored($1) ||
			    $self->warn("open \"$1\": $!");

		} elsif (m|^/|) {
			# absolute filename
			foreach my $filename (glob qq("$_")) {
				$self->{ignored}{$filename} = 1;
			}

		} elsif (s/^\@user\s+//) {
			# user entry
			$self->{ignored_users}{$_} = 1;

		} elsif (s/^\@group\s+//) {
			# group entry
			$self->{ignored_groups}{$_} = 1;

		} else {
			$self->err(1, "$conffile: invalid entry: $_");
		}
	}
	close($fh);
	return 1;
}

# walk the filesystem. the method will call `find_sub' overriden method.
sub walk_filesystem($self)
{
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

			# find_sub is defined per mode
			$self->find_sub($_);
		}
	    }, follow => 0, no_chdir => 1, }, '/');
}

# walk all users in the system.
sub walk_users($self)
{
	# walk users
	while (my ($name, $passwd, $uid, $gid, $quota, $class, $gecos, $home,
	           $shell, $expire) = getpwent()) {

		# only system users
		next if ($uid >= 1000);

		my $gname = getgrgid($gid) || $gid;
		my $user = join(':', ($name, $uid, $gname, $class, $home, $shell));
		my $user_gid = join(':', ($name, $uid, $gid, $class, $home, $shell));

		# check both $user and $user_gid,
		# as @newuser in ports could be both.
		if (!exists($self->{ignored_users}{$user}) &&
		    !(exists($self->{users}{$user}) ||
		      exists($self->{users}{$user_gid})) ) {

			my $short = join(':', ($name, $uid));

			if (exists($self->{users}{$short})) {
				# user exists, but it seems modified
				print('@user ', $user, " (modified)\n");
			} else {
				# not expected user
				print('@user ', $user, "\n");
			}
		}
	}
	endpwent();
}

# walk all groups in the system.
sub walk_groups($self)
{
	# walk groups
	while (my ($name, $passwd, $gid, $members) = getgrent()) {
		# only system groups
		next if ($gid >= 1000);

		my $group = join(':', ($name, $gid));

		if (!exists($self->{ignored_groups}{$group}) &&
		    !exists($self->{groups}{$group})) {

			# not expected group
			print('@group ', $group, "\n");
		}
	}
	endgrent();
}

sub walk($self)
{
	$self->walk_users;
	$self->walk_groups;
	$self->walk_filesystem;
}


#
# specialized versions
#

package sysclean::allfiles;
use parent -norequire, qw(sysclean);

sub find_sub($self, $filename)
{
	print($filename, "\n");
}

package sysclean::files;
use parent -norequire, qw(sysclean);

use OpenBSD::LibSpec;

sub add_expected_base_one($self, $filename)
{
	$self->SUPER::add_expected_base_one($filename);

	# track libraries (should not contains duplicate)
	if ($filename =~ m|/lib([^/]+)\.so\.\d+\.\d+$|o) {
		$self->{libs}{$1} = OpenBSD::Library->from_string($filename);
	}
}

sub find_sub($self, $filename)
{
	if ($filename =~ m|/lib([^/]*)\.so(\.\d+\.\d+)$|o) {

		if (exists($self->{used_libs}{"$1$2"})) {
			# skip used-libs (from ports)
			return;
		}

		if (exists($self->{libs}{$1})) {
			# skip if file from expected is not better than current
			my $expectedlib = $self->{libs}{$1};
			my $currentlib = OpenBSD::Library->from_string($filename);

			if ($currentlib->is_better($expectedlib)) {
				$self->warn("discard better version: $filename");
				return;
			}
		}
	}

	print($filename, "\n");
}

package sysclean::packages;
use parent -norequire, qw(sysclean);

sub add_expected_rcctl($self)
{
	# skip add_expected_rcctl: it shouldn't contain libraries
}

sub add_expected_users($self)
{
	# skip add_expected_users
}

sub plist_reader($self)
{
	return \&OpenBSD::PackingList::DependOnly;
}

sub walk($self)
{
	$self->walk_filesystem;
}

sub find_sub($self, $filename)
{
	if ($filename =~ m|/lib([^/]*)\.so(\.\d+\.\d+)$|o) {
		my $wantlib = "$1$2";

		for my $pkgname (@{$self->{used_libs}{$wantlib}}) {
			print($filename, "\t", $pkgname, "\n")
		}
	}
}


#
# extent OpenBSD::PackingElement for walking
#

package OpenBSD::PackingElement;
sub walk_sysclean($item, $pkgname, $sc)
{
}

package OpenBSD::PackingElement::Cwd;
sub walk_sysclean($item, $pkgname, $sc)
{
	use File::Basename;

	my $path = $item->name;

	do {
		$sc->{expected}{$path} = 1;
		$path = dirname($path);
	} while ($path ne "/");
}

package OpenBSD::PackingElement::FileObject;
sub walk_sysclean($item, $pkgname, $sc)
{
	my $filename = $item->fullname;

	# link: /usr/local/lib/X11/app-defaults/ -> /etc/X11/app-defaults/
	$filename =~ s|^/usr/local/lib/X11/app-defaults/|/etc/X11/app-defaults/|o;

	$sc->{expected}{$filename} = 1;
}

package OpenBSD::PackingElement::NewGroup;
sub walk_sysclean($item, $pkgname, $sc)
{
	my $group = join(':', map { $item->{$_} }
	    qw(name gid));

	$sc->{groups}{$group} = 1;
}

package OpenBSD::PackingElement::NewUser;
sub walk_sysclean($item, $pkgname, $sc)
{
	my $user = join(':', map { $item->{$_} }
	    qw(name uid group class home shell));
	my $short = join(':', map { $item->{$_} }
	    qw(name uid));

	$sc->{users}{$user} = 1;
	$sc->{users}{$short} = 1;
}

package OpenBSD::PackingElement::Sampledir;
sub walk_sysclean($item, $pkgname, $sc)
{
	$sc->{ignored}{$item->fullname} = 1;
}

package OpenBSD::PackingElement::Wantlib;
sub walk_sysclean($item, $pkgname, $sc)
{
	push(@{$sc->{used_libs}{$item->name}}, $pkgname);
}


#
# main program
#
package main;

use Getopt::Std;

my %options = ();	# program flags

getopts("apih", \%options) || sysclean->usage;
sysclean->usage if (defined $options{h} || scalar(@ARGV) != 0);

sysclean->err(1, "need root privileges") if ($> != 0);

sysclean->create(\%options)->walk;
