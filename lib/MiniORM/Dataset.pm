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

	push @{ $self->{tables} }, (map {$self->{orm}->pluralize(lc($_)) } @tables);

	return $self;
}

sub where {
	my ($self, @where) = @_;

	push @{ $self->{where} }, @where;

	return $self;
}

sub _sql_select {
	my ($self, %attr) = @_;

	return $self->{orm}->error("No tables to select from")
		unless @{$self->{tables}};

	my $cols = join(", ", @{$self->{cols}}) || "*";
	my $tables = join(", ", @{$self->{tables}});
	my $where = $self->transform_where(@{$self->{where}});

	my $sql = "SELECT $cols FROM $tables WHERE $where";

        if (%attr && $attr{limit} && $attr{limit} =~ /^[0-9]+$/) {
		$sql .= " LIMIT $attr{limit}";
	}

	return $sql;
}

sub delete {
	my ($self) = @_;

	if (scalar @{$self->{tables}} == 1) {
		my $where = $self->transform_where(@{$self->{where}});
		my $sql = "DELETE FROM $self->{tables}->[0] WHERE $where";

		my $sth = $self->{orm}->{dbh}->prepare($sql);
		if (!$self->{orm}->{dbh}->err) {
			return $self->{orm}->{dbh}->errstr;
		}

		$sth->execute(@{ $self->{binding} });
		if (!$self->{orm}->{dbh}->err) {
			return $self->{orm}->error($self->{orm}->{dbh}->errstr);
		}

		$self = undef;
		return 1;
	} else {
		return $self->{orm}->error("Cannot delete from 0 or more than 1 tables.");
	}
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

	my $conds = join(" AND ", @conds);
	$self->{binding} = \@bind;

	return $conds;
}

sub all {
	my ($self) = @_;

	my $sql = $self->_sql_select
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
			ucfirst($model),
			$self->{orm},
			$row->{id},
			%$row
		));
	}

	return @rs;
}

sub first {
	my ($self) = @_;

	my $sql = $self->_sql_select(limit => 1)
		or return;

	my $model;
	if (scalar @{$self->{tables}} == 1) {
		$model = $self->{tables}->[0];
	} else {
		$model = "_".join("__", @{$self->{tables}});
	}

	my $sth = $self->{orm}->{dbh}->prepare($sql);
	$sth->execute(@{ $self->{binding} });
	while (my $row = $sth->fetchrow_hashref) {
		return (MiniORM::Model->new(
			ucfirst($model),
			$self->{orm},
			$row->{id},
			%$row
		));
	}

	return;
}

1;

