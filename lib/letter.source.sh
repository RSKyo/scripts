#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Source-only library: Unicode letter helpers
#

# Prevent multiple sourcing
[[ -n "${__LETTER_SOURCED+x}" ]] && return 0
__LETTER_SOURCED=1

# Normalize user-friendly script names to Unicode Script
__normalize_script() {
  case "$1" in
    latin|Latin)       echo Latin ;;
    han|Han|cjk|CJK)   echo Han ;;
    hira|hiragana)     echo Hiragana ;;
    kata|katakana)     echo Katakana ;;
    hangul|kr|korean)  echo Hangul ;;
    greek)             echo Greek ;;
    cyrillic)          echo Cyrillic ;;
    arabic)            echo Arabic ;;
    *)                 return 1 ;;
  esac
}

# Count all Unicode letters (\p{L})
letter_count() {
  local text="$1"

  __perl '
    use strict; use warnings;
    my $s = join("", <>);
    my $count = 0;

    foreach my $ch (split(//, $s)) {
      $count++ if $ch =~ /\p{L}/;
    }

    print $count;
  ' <<< "$text"
}

# Count letters by Unicode Script
letter_script_count() {
  local text="$1"
  local script
  script="$(__normalize_script "$2")" || return 1

  __perl '
    use strict; use warnings;

    my ($script) = @ARGV;
    my $s = join("", <>);
    my $count = 0;

    foreach my $ch (split(//, $s)) {
      $count++ if $ch =~ /\p{Script=$script}/;
    }

    print $count;
  ' "$script" <<< "$text"
}

# Ratio of a Unicode Script among all letters
letter_script_ratio() {
  local text="$1"
  local script
  script="$(__normalize_script "$2")" || return 1

  __perl '
    use strict; use warnings;

    my ($script) = @ARGV;
    my $s = join("", <>);

    my $total  = 0;
    my $target = 0;

    foreach my $ch (split(//, $s)) {
      next unless $ch =~ /\p{L}/;
      $total++;
      $target++ if $ch =~ /\p{Script=$script}/;
    }

    if ($total == 0) {
      print 0;
    } else {
      printf "%.6f", $target / $total;
    }
  ' "$script" <<< "$text"
}

# Trim non-letter characters from both ends
letter_trim() {
  local text="$1"

  __perl '
    use strict; use warnings;
    my $s = join("", <>);

    $s =~ s/^\P{L}+//;
    $s =~ s/\P{L}+$//;

    print $s;
  ' <<< "$text"
}

# Trim non-letter-or-digit characters from both ends
alnum_trim() {
  local text="$1"

  __perl '
    use strict; use warnings;
    my $s = join("", <>);

    # trim leading non-letter/digit
    $s =~ s/^[^\p{L}0-9]+//;

    # trim trailing non-letter/digit
    $s =~ s/[^\p{L}0-9]+$//;

    print $s;
  ' <<< "$text"
}


# Get position of first letter (1-based)
first_letter_pos() {
  local str="$1"

  __perl '
    use strict; use warnings;
    my $s = join("", <>);
    my $i = 1;   # 1-based index

    foreach my $ch (split(//, $s)) {
      if ($ch =~ /\p{L}/) {
        print $i;
        exit 0;
      }
      $i++;
    }

    print 0;
  ' <<< "$str"
}

# Get position of last letter (1-based)
last_letter_pos() {
  local str="$1"

  __perl '
    use strict; use warnings;
    my $s   = join("", <>);
    my $pos = -1;
    my $i = 1;   # 1-based index

    foreach my $ch (split(//, $s)) {
      $pos = $i if $ch =~ /\p{L}/;
      $i++;
    }

    print $pos;
  ' <<< "$str"
}
