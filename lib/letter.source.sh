#!/usr/bin/env bash
# letter.source.sh
# letter utilities module.

# shellcheck disable=SC2016

# Prevent multiple sourcing
# [[ -n "${__LETTER_SOURCED+x}" ]] && return 0
# __LETTER_SOURCED=1

# Normalize user-friendly script names to Unicode Script
# shellcheck disable=SC2034
__letter_normalize_script_into() {
  local -n out="$1"
  local name="$2"
  case "$name" in
    latin|Latin)       out=Latin ;;
    han|Han|cjk|CJK)   out=Han ;;
    hira|hiragana)     out=Hiragana ;;
    kata|katakana)     out=Katakana ;;
    hangul|kr|korean)  out=Hangul ;;
    greek)             out=Greek ;;
    cyrillic)          out=Cyrillic ;;
    arabic)            out=Arabic ;;
    *)                 out= ;;
  esac
}

# Count Unicode letters.
# - If script is provided, counts letters of that script.
# - If script is empty, counts all letters (\p{L}).
# - Output always ends with a newline.
letter_count() {
  local input="$1"
  local script
  __normalize_script_into script "${2:-}"

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