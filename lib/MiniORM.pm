package MiniORM;

use 5.022001;
use strict;
use warnings;
use DBI;

use MiniORM::Model;
use MiniORM::Dataset;

use vars qw($AUTOLOAD);

our $VERSION = '0.1';
our @SUPPORTED_DRIVERS = qw(Pg SQLite);
our $errstr;

sub new {
	my ($class, $param) = @_;

	if (ref $param ne 'HASH') {
		$errstr = 'Cannot build DSN string.';
		return;
	}

	unless (grep { $param->{driver} eq $_ } @SUPPORTED_DRIVERS) {
		die "MiniORM: unsupported driver $param->{driver}, supported: "
			. join(", ", @SUPPORTED_DRIVERS) . ".";
	}

	my $driver = $param->{driver};
	my $dsn = "dbi:$driver:dbname=$param->{db}";
	my $dbh = DBI->connect($dsn);

	if (!$dbh) {
		$errstr = $DBI::errstr;
		return;
	}

	if ($driver eq 'SQLite') {
		my $sth = $dbh->prepare("PRAGMA foreign_keys = ON");
		$sth->execute();
	}

	my $self = {
		driver	=> $driver,
		dbh	=> $dbh,
		plurals => {},
	};

	bless $self, $class;
	return $self;
}

sub AUTOLOAD {
	my $sub = $AUTOLOAD;
	my ($miniorm, @args) = (@_);

	$sub =~ s/.*:://;
	if ($sub !~ /^[A-Z][A-Za-z0-9_]*$/) {
		die "MiniORM: undefined subroutine '$sub'.";
	}

	my $model = MiniORM::Model->new($sub, $miniorm, undef, @args);

	return $model;
}

sub get_last_id {
	my ($self) = @_;

	my $id;

	if ($self->{driver} eq 'Pg') {
		($id) = $self->{dbh}->selectrow_array("SELECT lastval()");
	} elsif ($self->{driver} eq 'SQLite') {
		($id) = $self->{dbh}->selectrow_array("SELECT last_insert_rowid()");
	}

	return $id;
}

sub error {
	my ($self, $local_errstr) = @_;

	$MiniORM::errstr = $local_errstr;

	return;
}

sub pluralize {
	my ($self, $singular, $plural) = @_;

	if ($singular && $plural) {
		$self->{plurals}->{$singular} = $plural;
	} elsif ($singular && !$self->{plurals}->{$singular}) {
		if ($singular =~ /s$/) {
			$plural = $singular;
		} elsif ($singular =~ /y$/) {
			$plural = $singular;
			$plural =~ s/y$/ies/;
		} else {
			$plural = $singular . "s";
		}
		$self->{plurals}->{$singular} = $plural;
	}

	return $self->{plurals}->{$singular};
}

1;
__END__

=head1 NAME

MiniORM - Simple SQL generator

=head1 SYNOPSIS

  use MiniORM;

  my $DB = MiniORM->new({
    driver => 'sqlite',
    db     => 'test.db',
  });

  $DB->Users->insert({ name => "tom14159" });

=head1 DESCRIPTION

Stub documentation for MiniORM, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

tomas.zabojnik, E<lt>tomaszabojnik@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by tomas.zabojnik

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
