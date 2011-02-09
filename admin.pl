
sub master {
  my %args = @_;

  my ($to, $msg, $data, $trans,
      $self, $arg, $nick, $userhost) = ($args{to},
                                        $args{msg},
                                        $args{data},
                                        $args{trans},
                                        $args{self},
                                        $args{arg},
                                        $args{nick},
                                        $args{userhost}
    );

  if ($userhost !~ m/$trans->{userhost}/i) {
    return +{
      data => $data,
      trans => $trans,
      to => $nick,
      msg => "Nice try",
    };
  }

  # master commands
  if ($arg =~ /^say (\S+) (.+)/i) {
    $to = $1;
    $msg = $2;
  }
  elsif ($arg =~ /^join (.*)/) {
    my $newchan = $1;
    $newchan = "#$newchan" unless $newchan =~ m/^#/;
    $self->join($newchan);

    $trans->{stfu}->{$newchan} = 0;
    $msg .= "joining $newchan";
  }
  elsif ($arg =~ /^deop (\S+) (.+)/) {
    $to = $2;
    $self->mode("$2", "-o", $1);
    $msg = 'The Lord giveth and the lord taketh away...';
  }
  elsif ($arg =~ /^op (\S+) (.+)/) {
    $to = $nick;
    $self->mode("$2", "+o", $1);
    $msg .= "op $1 on $2";
  }
  elsif ($arg =~ /^dumptrans\s*(.*)/) {
    if ($1) {
      $to = $nick;
      $msg = Dumper($trans->{$1});
    }
    else {
      print Dumper($trans);
      undef $msg;
    }
  }
  elsif ($arg =~ /^keystrans\s*(.*)/) {
    if ($1) {
      $to = $nick;
      $msg = join(' ', ref($trans->{$1}) eq 'HASH'
                  ? keys %{$trans->{$1}}
                  : $trans->{$1}
        );
    }
    else {
      $to = $nick;
      $msg = join(' ', keys %$trans);
    }
  }
  elsif ($arg =~ /^dump\s*(.*)/) {
    if ($1) {
      $to = $nick;
      $msg = Dumper($data->{$1});
    }
    else {
      print Dumper($data);
      undef $msg;
    }
  }
  elsif ($arg =~ /^keys\s*(.*)/) {
    if ($1) {
      $to = $nick;
      $msg = join(' ', ref($data->{$1}) eq 'HASH'
                  ? keys %{$data->{$1}}
                  : $data->{$1}
        );
    }
    else {
      $to = $nick;
      $msg = join(' ', keys %$data);
    }
  }
  elsif ($arg =~ /^cleanfacts/) {
    for my $key (keys %{$data->{facts}}) {
      if ($key =~ m/\s/) {
        delete $data->{facts}->{$key};
      }
    }
  }
  elsif ($arg =~ /^jsondump/) {
    &write_data();
    $msg = "Dumped.";
  }
  elsif ($arg =~ /^die/) {
    &write_data();
    for my $chan (keys %{$trans->{stfu}}) {
      for my $master (@{$trans->{master}}, "pendingo") {
        $self->mode($chan, "+o", $master);
      }
    }
    exit();
  }
  elsif ($arg =~ /^setdata\s+(\S*)\s+(.*)/) {
    my ($k, $v) = ($1, $2);
    if ($k =~ m/__/) {
      my ($k1, $k2) = split(/__/, $k);
      $data->{$k1}->{$k2} = $v;
    }
    else {
      $data->{$k} = $v;
    }
    $msg = "Updated";
  }
  elsif ($arg =~ /^killdata\s+(\S*)/) {
    my $k = $1;
    if ($k =~ m/__/) {
      my ($k1, $k2) = split(/__/, $k);
      delete $data->{$k1}->{$k2};
    }
    else {
      delete $data->{$1};
    }
    $msg .= "baleeted.";
  }

  return +{
    data => $data,
    trans => $trans,
    to => $to,
    msg => $msg
  };
}

sub mkpasswd {
  my $what = $_[0];
  my $salt = chr(33+rand(64)).chr(33+rand(64));
  $salt =~ s/:/;/g;

  return crypt($what, $salt);
}

sub ckpasswd {
    # returns true if arg1 encrypts to arg2
  my ($plain, $encrypted) = @_;
  if (!$encrypted) {
    ($plain, $encrypted) = split(/\s+/, $plain, 2);
  }
  return '' unless ($plain && $encrypted);
  return ($encrypted eq crypt($plain, $encrypted));
}

1;
