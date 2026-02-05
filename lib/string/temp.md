Script	Perl 表达式	包含
拉丁	\p{Script=Latin}	英文 + 带重音字母
汉字	\p{Script=Han}	中文 / 日文汉字
日文假名	\p{Script=Hiragana} / \p{Script=Katakana}	かな / カナ
韩文	\p{Script=Hangul}	한글
希腊	\p{Script=Greek}	Ελληνικά
西里尔	\p{Script=Cyrillic}	Русский


perl -CS -Mutf8 -e '
  use strict;
  use warnings;

  my $s = join("", <>);

  my $total = 0;   # all language letters: \p{L}
  my $en    = 0;   # English letters: A-Za-z

  foreach my $ch (split(//, $s)) {
    next unless $ch =~ /\p{L}/;
    $total++;
    $en++ if $ch =~ /[A-Za-z]/;
  }

  if ($total == 0) {
    printf("%.3f\n", 0);
  } else {
    printf("%.3f\n", $en / $total);
  }
' <<< "$str"
