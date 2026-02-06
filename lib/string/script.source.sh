#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# string/script.source.sh
#
# Unicode-aware string utilities (letters & scripts).
#
# Design principles:
# - All character-level operations are delegated to Perl (Unicode-safe).
# - Bash layer only composes results; no byte-based slicing.
# - This module provides primitive facts, not business logic.
#
# -----------------------------------------------------------------------------

# Prevent multiple sourcing
[[ -n "${__STRING_SCRIPT_SOURCED+x}" ]] && return 0
__STRING_SCRIPT_SOURCED=1

# -----------------------------------------------------------------------------
# Internal helper: run Unicode-safe Perl snippet
# -----------------------------------------------------------------------------
__string_perl() {
  perl -CS -Mutf8 -e "$1" "${@:2}"
}

# -----------------------------------------------------------------------------
# Internal helper: count characters of a given Unicode Script
# -----------------------------------------------------------------------------
__string_script_count() {
  local str="$1"
  local script="$2"

  __string_perl '
    use strict; use warnings;

    my ($script) = @ARGV;
    my $s = join("", <>);
    my $count = 0;

    foreach my $ch (split(//, $s)) {
      $count++ if $ch =~ /\p{Script=$script}/;
    }

    print $count;
  ' "$script" <<< "$str"
}

# -----------------------------------------------------------------------------
# Script-specific counters (public API)
# -----------------------------------------------------------------------------
string_han_count() {
  __string_script_count "$1" Han
}

string_latin_count() {
  __string_script_count "$1" Latin
}

string_hiragana_count() {
  __string_script_count "$1" Hiragana
}

string_katakana_count() {
  __string_script_count "$1" Katakana
}

string_hangul_count() {
  __string_script_count "$1" Hangul
}



# -----------------------------------------------------------------------------
# Script profile: count per Unicode Script (stable output order)
# -----------------------------------------------------------------------------
string_script_profile() {
  local str="$1"

  __string_perl '
    use strict; use warnings;
    my $s = join("", <>);

    my %cnt;

    foreach my $ch (split(//, $s)) {
      next unless $ch =~ /\p{L}/;

      if    ($ch =~ /\p{Script=Han}/)        { $cnt{Han}++ }
      elsif ($ch =~ /\p{Script=Hiragana}/)  { $cnt{Hiragana}++ }
      elsif ($ch =~ /\p{Script=Katakana}/)  { $cnt{Katakana}++ }
      elsif ($ch =~ /\p{Script=Hangul}/)    { $cnt{Hangul}++ }
      elsif ($ch =~ /\p{Script=Latin}/)     { $cnt{Latin}++ }
      elsif ($ch =~ /\p{Script=Cyrillic}/)  { $cnt{Cyrillic}++ }
      elsif ($ch =~ /\p{Script=Greek}/)     { $cnt{Greek}++ }
      elsif ($ch =~ /\p{Script=Arabic}/)    { $cnt{Arabic}++ }
      else                                   { $cnt{Other}++ }
    }

    my @order = qw(
      Han
      Hiragana
      Katakana
      Hangul
      Latin
      Cyrillic
      Greek
      Arabic
      Other
    );

    for my $k (@order) {
      print "$k=$cnt{$k}\n" if exists $cnt{$k};
    }
  ' <<< "$str"
}
