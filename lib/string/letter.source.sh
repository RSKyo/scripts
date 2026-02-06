#!/usr/bin/env bash


# Prevent multiple sourcing
[[ -n "${__STRING_LETTER_SOURCED+x}" ]] && return 0
__STRING_LETTER_SOURCED=1

# -----------------------------------------------------------------------------
# Internal helper: run Unicode-safe Perl snippet
# -----------------------------------------------------------------------------
__string_perl() {
  perl -CS -Mutf8 -e "$1" "${@:2}"
}

# -----------------------------------------------------------------------------
# Count Unicode letters (\p{L})
# -----------------------------------------------------------------------------
string_letter_count() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s = join("", <>);
    my $count = 0;

    foreach my $ch (split(//, $s)) {
      $count++ if $ch =~ /\p{L}/;
    }

    print $count;
  ' <<< "$str"
}

# -----------------------------------------------------------------------------
# Count non-letter characters (\P{L})
# -----------------------------------------------------------------------------
string_nonletter_count() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s = join("", <>);
    my $count = 0;

    foreach my $ch (split(//, $s)) {
      $count++ if $ch =~ /\P{L}/;
    }

    print $count;
  ' <<< "$str"
}

# -----------------------------------------------------------------------------
# First Unicode letter position (0-based)
# -----------------------------------------------------------------------------
string_first_letter_pos() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s = join("", <>);
    my $i = 0;

    foreach my $ch (split(//, $s)) {
      if ($ch =~ /\p{L}/) {
        print $i;
        exit 0;
      }
      $i++;
    }

    print -1;
  ' <<< "$str"
}

# -----------------------------------------------------------------------------
# Last Unicode letter position (0-based)
# -----------------------------------------------------------------------------
string_last_letter_pos() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s   = join("", <>);
    my $pos = -1;
    my $i   = 0;

    foreach my $ch (split(//, $s)) {
      $pos = $i if $ch =~ /\p{L}/;
      $i++;
    }

    print $pos;
  ' <<< "$str"
}

# -----------------------------------------------------------------------------
# First Unicode letter (character itself)
# -----------------------------------------------------------------------------
string_first_letter() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s = join("", <>);

    foreach my $ch (split(//, $s)) {
      if ($ch =~ /\p{L}/) {
        print $ch;
        exit 0;
      }
    }
  ' <<< "$str"
}

# -----------------------------------------------------------------------------
# Last Unicode letter (character itself)
# -----------------------------------------------------------------------------
string_last_letter() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s = join("", <>);
    my $last = "";

    foreach my $ch (split(//, $s)) {
      $last = $ch if $ch =~ /\p{L}/;
    }

    print $last if length $last;
  ' <<< "$str"
}