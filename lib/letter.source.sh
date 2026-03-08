#!/usr/bin/env bash
# Source-only library: lib/letter
# shellcheck disable=SC2016

# --- Source Guard ------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__LETTER_SOURCED+x}" ]] && return 0
__LETTER_SOURCED=1

# --- Internal Helpers --------------------------------------------------------

__letter_script_canonicalize() {
  local -n _script_ref="$1"
  local _script="$2"
  case "$_script" in
    latin|Latin)       _script_ref=Latin ;;
    han|Han|cjk|CJK)   _script_ref=Han ;;
    hira|hiragana)     _script_ref=Hiragana ;;
    kata|katakana)     _script_ref=Katakana ;;
    hangul|kr|korean)  _script_ref=Hangul ;;
    greek)             _script_ref=Greek ;;
    cyrillic)          _script_ref=Cyrillic ;;
    arabic)            _script_ref=Arabic ;;
    *)                 _script_ref= ;;
  esac
}

# --- Public API --------------------------------------------------------------

# Count Unicode letters.
# - If script is provided, counts letters of that script.
# - If script is empty, counts all letters (\p{L}).
# - Output always ends with a newline.
letter_count() {
  local input="$1"
  local script
  __letter_script_canonicalize script "${2:-}"

  __perl '
    use strict;
    use warnings;

    my $script = shift @ARGV // "";
    my $s = join("", <>);
    # remove the newline added by <<< (only one)
    $s =~ s/\n\z//;

    my $count;

    if ($script eq "") {
        $count = () = $s =~ /\p{L}/g;
    } else {
        $count = () = $s =~ /\p{Script=\Q$script\E}/g;
    }

    print "$count\n";
  ' "$script" <<< "$input"
}

# Trim non-letter characters from both ends.
# - Keeps all Unicode letters (\p{L}).
# - Optionally keeps extra literal characters (2nd argument).
# - Extra is treated as a plain character set (not a regex).
letter_trim() {
  local input="$1"
  local extra="${2:-}"

  __perl '
    use strict;
    use warnings;

    my $extra = shift @ARGV;
    my $s = join("", <>);
    # remove the newline added by <<< (only one)
    $s =~ s/\n\z//;

    $s =~ s/^[^\p{L}\Q$extra\E]+//;
    $s =~ s/[^\p{L}\Q$extra\E]+$//;

    print "$s\n";
  ' "$extra" <<< "$input"
}

# Normalize Unicode letters by compatibility decomposition.
# - Applies NFKD normalization.
# - Removes all combining marks (\p{M}).
# - Useful for converting styled/math letters to plain letters.
# - Output always ends with a newline.
letter_demath() {
  local input="$1"

  __perl '
    use strict;
    use warnings;
    use Unicode::Normalize;

    my $s = join("", <>);
    # remove the newline added by <<< (only one)
    $s =~ s/\n\z//;

    # Compatibility decomposition
    $s = NFKD($s);

    # Remove combining marks
    $s =~ s/\p{M}//g;

    print "$s\n";
  ' <<< "$input"
}

# Return the 1-based position of the first Unicode letter.
# - A letter is defined by \p{L}.
# - Returns 0 if no letter is found.
# - Output always ends with a newline.
first_letter_pos() {
  local input="$1"

  __perl '
    use strict;
    use warnings;

    my $s = join("", <>);
    # remove the newline added by <<< (only one)
    $s =~ s/\n\z//;

    if ($s =~ /(\p{L})/) {
        print (($-[1] + 1) . "\n");
    } else {
        print "0\n";
    }
  ' <<< "$input"
}

# Return the 1-based position of the last Unicode letter.
# - A letter is defined by \p{L}.
# - Returns 0 if no letter is found.
# - Output always ends with a newline.
last_letter_pos() {
  local input="$1"

  __perl '
    use strict;
    use warnings;

    my $s = join("", <>);
    # remove the newline added by <<< (only one)
    $s =~ s/\n\z//;

    if ($s =~ /(\p{L})(?!.*\p{L})/s) {
      print (($-[1] + 1) . "\n");
    } else {
      print "0\n";
    }
  ' <<< "$input"
}

# letter_slice <string> <start> [end]
# Return substring using 1-based character positions.
# Invalid positions default to 1.
# If [end] is omitted, slice to end of string.
# Always returns 0.
letter_slice() {
  local input="${1-}"
  local start="${2-1}"
  local end="${3-}"

  [[ -n "$input" ]] || { printf '%s\n' ''; return 0; }
  [[ "$start" =~ ^[1-9][0-9]*$ ]] || start=1
  [[ "$end" =~ ^[1-9][0-9]*$ ]] || end=

  __perl '
    use strict;
    use warnings;

    my $start = shift @ARGV;
    my $end   = shift @ARGV;
    my $s     = join("", <>);
    # remove the newline added by <<< (only one)
    $s =~ s/\n\z//;

    my $len = length($s);

    $start = 1 if $start < 1;

    # start beyond end of string -> empty
    if ($start > $len) { print ""; exit 0; }

    # end omitted/invalid -> to end
    $end = $len if $end eq "";

    # clamp end into [1..len]
    $end = 1   if $end < 1;
    $end = $len if $end > $len;

    # end before start -> empty
    if ($end < $start) { print ""; exit 0; }

    my $offset = $start - 1;
    my $length = $end - $start + 1;

    print substr($s, $offset, $length), "\n";
  ' "$start" "$end" <<< "$input"
}

letter_ratio_cmp() {
  local input="$1"
  local script
  __letter_script_canonicalize script "${2:-}"
  local op="$3"
  local b="$4"

  __perl '
    use strict;
    use warnings;
    use utf8;

    my $script = shift @ARGV;
    my $op     = shift @ARGV;
    my $b      = shift @ARGV;

    my $s = join("", <>);
    $s =~ s/\n\z//;

    my $total = () = $s =~ /\p{L}/g;
    exit 1 if $total == 0;

    my $count = () = $s =~ /\p{Script=$script}/g;

    my $ratio = $count / $total;

    my $ok =
         $op eq "gt" ? $ratio >  $b
      :  $op eq "ge" ? $ratio >= $b
      :  $op eq "lt" ? $ratio <  $b
      :  $op eq "le" ? $ratio <= $b
      :  $op eq "eq" ? $ratio == $b
      :  $op eq "ne" ? $ratio != $b
      :  die "invalid operator";

    exit($ok ? 0 : 1);
  ' "$script" "$op" "$b" <<< "$input"
}

letter_split_segments() {
  local input="$1"

  __perl '
    use strict;
    use warnings;

    my $s = join("", <>);
    $s =~ s/\n\z//;

    while ($s =~ /(
        \[[^\]]+\] |
        [\p{Latin}\p{N}]+(?:\s+[\p{Latin}\p{N}]+)* |
        [\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]+(?:\s+[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]+)* |
        \S
    )/gx) {
        print "$1\n";
    }
  ' <<< "$input"
}
