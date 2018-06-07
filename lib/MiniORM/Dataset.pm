package MiniORM::Dataset;

use 5.022001;
use strict;
use warnings;
use List::Util qw(pairs);

sub new {
	my ($class, $orm) = @_;

	my $self = {
		orm     => $orm,
		tables  => [],
		cols    => [],
		where   => [],
		order   => [],
		group   => [],
		sql     => "",
		binding => [],
	};

	bless $self, $class;
	return $self;
}

sub from {
	my ($self, @tables) = @_;

	push @{ $self->{tables} }, @tables;

	return $self;
}

sub where {
	my ($self, @where) = @_;

	push @{ $self->{where} }, @where;

	return $self;
}

sub sql_select {
	my ($self) = @_;

	return $self->{orm}->error("No tables to select from")
		unless @{$self->{tables}};

	my $cols = join(", ", @{$self->{cols}}) || "*";
	my $tables = join(", ", @{$self->{tables}});
	my $where = join(" AND ", $self->transform_where(@{$self->{where}}));

	return "SELECT $cols FROM $tables WHERE $where";
}

sub transform_where {
	my ($self, @where) = @_;

	my @conds;
	my @bind;

	if (!@where) {
		push @conds, ("1=1");
	}

	for my $pair (pairs @where) {
		my ($left, $right) = @$pair;

		if (ref $right eq 'ARRAY') {
			push @conds, (
				"($left IN ("
				. join (", ", map { "?" } @$right)
				."))");
			push @bind, (@$right);
		} elsif (ref $right eq 'HASH') {
			if ($right->{is} && lc $right->{is} eq "null") {
				push @conds, ("($left IS NULL)");
			} elsif ($right->{is} && lc $right->{is} eq "not null") {
				push @conds, ("($left IS NOT NULL)");
			} elsif ($right->{not}) {
				push @conds, ("($left != ?)");
				push @bind, ($right->{not});
			} elsif ($right->{like}) {
				push @conds, ("($left LIKE ?)");
				push @bind, ($right->{like});
			}
		} else {
			push @conds, ("($left = ?)");
			push @bind, ($right);
		}
	}

	$self->{binding} = \@bind;

	return @conds;
}

sub all {
	my ($self) = @_;

	my $sql = $self->sql_select
		or return;

	my @rs;

	my $model;
	if (scalar @{$self->{tables}} == 1) {
		$model = $self->{tables}->[0];
	} else {
		$model = "_".join("__", @{$self->{tables}});
	}

	my $sth = $self->{orm}->{dbh}->prepare($sql);
	$sth->execute(@{ $self->{binding} });
	while (my $row = $sth->fetchrow_hashref) {
		push @rs, (MiniORM::Model->new(
			$model,
			$self->{orm},
			$row->{id},
			%$row
		));
	}

	return @rs;
}

1;

