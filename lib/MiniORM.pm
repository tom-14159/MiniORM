package MiniORM;

use 5.022001;
use strict;
use warnings;
use DBI;

use vars qw($AUTOLOAD);

our $VERSION = '0.1';
our $errstr;

sub new {
	my ($class, $param) = @_;

	if (ref $param ne 'HASH') {
		$errstr = 'Cannot build DSN string.';
		return;
	}

	my $driver = $param->{driver};
	my $dsn = "dbi:$driver:dbname=$param->{db}";
	my $dbh = DBI->connect($dsn);

	if (!$dbh) {
		$errstr = $DBI::errstr;
		return;
	}

	my $self = {
		driver	=> $driver,
		dbh	=> $dbh,
	};

	bless $self, $class;
	return $self;
}

sub AUTOLOAD {
	my $sub = $AUTOLOAD;
	my ($parent, @args) = (@_);

	$sub =~ s/.*:://;
	if ($sub !~ /^[A-Z][A-Za-z0-9_]*$/) {
		die "MiniORM: undefined subroutine '$sub'.";
	}

	my $model = MiniORM::Model->new($sub, $parent);
	$model->where(@args) if @args;

	return $model;
}

package MiniORM::Model;

sub new {
	my ($class, $name, $parent) = @_;

	my $self = {
		handler => $parent,
		name	=> $name,
		cst	=> [],
	};

	bless $self, $class;
	return $self;
}

sub where {
	my ($self, @cst) = @_;
	# TODO
}

sub insert {
	my ($self, %record) = @_;

	my @keys = keys %record;
	my @values = map { $record{$_} } @keys;

	my $sql = "INSERT INTO "
		. lc($self->{name})
		. " ("
		. join(", ", @keys)
		. ") VALUES ("
		. join(", ", map { "?" } @keys)
		. ")";

	my $sth = $self->{handler}->{dbh}->prepare($sql);
	$sth->execute(@values);

	if ($self->{handler}->{dbh}->err) {
		$MiniORM::errstr = $self->{handler}->{dbh}->errstr;
		return;
	}

	return 1;
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
