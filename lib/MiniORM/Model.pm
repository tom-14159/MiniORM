package MiniORM::Model;

use 5.022001;
use strict;
use warnings;

use vars qw($AUTOLOAD);

sub new {
	my ($class, $name, $orm, $id, %attrs) = @_;

	die "MiniORM::Model: Invalid model name '$name'."
		unless $name =~ /^[A-Z_][A-Za-z0-9_]*$/;

	my $self = {
		id     => $id,
		orm    => $orm,
		model  => $name,
		fields => {},
	};

	bless $self, $class;
	return $self->set(%attrs);
}

sub set {
	my ($self, %attrs) = @_;

	if (%attrs) {
		for my $key (keys %attrs) {
			$self->{fields}->{$key} = $attrs{$key};
		}
	}

	return $self;
}

sub save {
	my ($self) = @_;

	if ($self->{model} =~ /^_/) {
		return $self->{orm}->error("MiniORM::Model: Cannot save pseudomodel '$self->{model}'.");
	}

	if ($self->{id}) {
		# UPDATE
                my @keys = keys %{$self->{fields}};
		my @values = map { $self->{fields}->{$_} } @keys;

		my $sql = "UPDATE "
			. $self->{orm}->pluralize(lc($self->{model}))
			. " SET "
			. join(", ", map { "$_ = ?" } @keys)
			. " WHERE id = ?";
		my $sth = $self->{orm}->{dbh}->prepare($sql);
		$sth->execute(@values, $self->{id});

		if ($self->{orm}->{dbh}->err) {
			return $self->{orm}->error($self->{orm}->{dbh}->errstr);
		}

		if (exists $self->{fields}->{id} && $self->{fields}->{id} ne $self->{id}) {
			$self->{id} = $self->{fields}->{id};
		}
	} else {
		# INSERT
		my @keys = grep { $_ ne "id" } keys %{$self->{fields}};
		my @values = map { $self->{fields}->{$_} } @keys;

		my $sql = "INSERT INTO "
			. $self->{orm}->pluralize(lc($self->{model}))
			. " ("
			. join(", ", @keys)
			. ") VALUES ("
			. join(", ", map { "?" } @keys)
			. ")";
		my $sth = $self->{orm}->{dbh}->prepare($sql);
		$sth->execute(@values);

		if ($self->{orm}->{dbh}->err) {
			return $self->{orm}->error($self->{orm}->{dbh}->errstr);
		}

		$self->{id} = $self->{orm}->get_last_id;

		$self->reload;
	}

	return $self;
}

sub reload {
	my ($self) = @_;

	if ($self->{id}) {
		my $sql = "SELECT * FROM ".$self->{orm}->pluralize(lc($self->{model}))." WHERE id = ?";
		my $attrs = $self->{orm}->{dbh}->selectrow_hashref($sql, {}, $self->{id});
		if ($attrs) {
			for my $key (keys %$attrs) {
				$self->{fields}->{$key} = $attrs->{$key};
			}
		}
	}

	return $self;
}

sub find {
	my ($self, @where) = @_;

	my $dataset = MiniORM::Dataset->new($self->{orm});

	return $dataset->from($self->{model})->where(@where);
}

sub all {
	my ($self, @where) = @_;

	my $dataset = MiniORM::Dataset->new($self->{orm});

	return $dataset->from($self->{model})->all();
}

sub AUTOLOAD {
	my $sub = $AUTOLOAD;
	my ($self, $arg) = @_;

	$sub =~ s/.*:://;
	$sub = lc $sub;
	if ($sub !~ /^[a-z0-9_]/) {
		die "MiniORM::Model $self->{name}: undefined subroutine '$sub'.";
	}

	if ($arg) {
		$self->{fields}->{$sub} = $arg;
		return $self;
	}

	return $self->{fields}->{$sub};
}

1;
