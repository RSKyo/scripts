#!/usr/bin/env bash

# ===============================================
# 剧集-学习字幕样式.sh
# ===============================================
#
# 单文件：
#   ./剧集-学习字幕样式.sh ass_study_style_file <file.ass>
# 目录批量：
#   ./剧集-学习字幕样式.sh ass_study_style_dir <dir>
#
# 输出：<file>_study.ass
# ===============================================

usage() {
  echo "用法:"
  echo "  $0 ass_study_style_file <file.ass>"
  echo "  $0 ass_study_style_dir  <dir>"
}

detect_encoding() {
  local file="$1"
  local bom
  bom="$(LC_ALL=C dd if="$file" bs=2 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  case "$bom" in
    fffe) echo "UTF-16LE" ;;
    feff) echo "UTF-16BE" ;;
    *)    echo "UTF-8" ;;
  esac
}

decode_to_utf8() {
  local file="$1"
  local encoding="$2"
  case "$encoding" in
    UTF-16LE|UTF-16BE) iconv -f UTF-16 -t UTF-8 "$file" ;;
    UTF-8) cat "$file" ;;
    *) echo "不支持的编码: $encoding" >&2; return 1 ;;
  esac
}

encode_from_utf8() {
  local encoding="$1"
  local output="$2"
  case "$encoding" in
    UTF-16LE) { printf '\xFF\xFE'; iconv -f UTF-8 -t UTF-16LE; } > "$output" ;;
    UTF-16BE) { printf '\xFE\xFF'; iconv -f UTF-8 -t UTF-16BE; } > "$output" ;;
    UTF-8) cat > "$output" ;;
    *) echo "不支持的编码: $encoding" >&2; return 1 ;;
  esac
}

apply_study_style_stream() {
  perl -Mutf8 -e "$(cat <<'PERL'
binmode(STDIN,  ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

local $/;
my $text = <STDIN>;
$text =~ s/^\x{FEFF}//;

my $new_header = <<'HEADER';
[Script Info]
ScriptType: v4.00+
Collisions: Normal
PlayResX: 384
PlayResY: 288
Timer: 100.0000
WrapStyle: 0
ScaledBorderAndShadow: no

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,17,&H00FFFFFF,&H000000FF,&H00000000,&H32000000,0,0,0,0,100,100,0,0,1,2,1,2,8,8,10,0
Style: Chs,Source Han Sans SC,15,&H00A0A0A0,&H000000FF,&H00000000,&H32000000,0,0,0,0,100,100,0,0,1,1,0,2,8,8,3,134

[Events]
HEADER

my $SEP = '\N{\rChs}';

# 替换头部到 [Events]
$text =~ s/\A.*?^\[Events\][^\S\r\n]*(?:\r?\n)?/$new_header/ms;

# 判断是否需要互换
my $need_swap = 0;
for my $line (split /\n/, $text) {
  next unless $line =~ /^Dialogue:/;
  if ($line =~ /^((?:[^,]*,){9})(.*)$/) {
    my ($meta,$body) = ($1,$2);
    # 统一分隔符
    $body =~ s/\\N(?:\{[^}]*\})+/$SEP/g;
    if(index($body,$SEP)>=0 && length($body) > 12) {
      my ($left,$right)=split /\Q$SEP\E/,$body,2;
      my $left_cjk = () = $left =~ /[\x{4E00}-\x{9FFF}]/g;
      my $right_letters = () = $right =~ /[A-Za-z]/g;
      if($left_cjk && $right_letters>=4) { $need_swap=1; last; }
      last;
    }
  }
}

my @out;
for my $line (split /\n/, $text, -1) {
  if($line =~ /^Dialogue:/) {
    # 统一 Style 字段为 Default
    $line =~ s/^(Dialogue:[^,]*,[^,]*,[^,]*,)[^,]*(,)/$1Default$2/;
    if($line =~ /^((?:[^,]*,){9})(.*)$/) {
      my ($meta,$body) = ($1,$2);
      # 统一分隔符
      $body =~ s/\\N(?:\{[^}]*\})+/$SEP/g;
      # 清理中英文残留换行
      my ($left,$right)=split /\Q$SEP\E/,$body,2;
      $left =~ s/[\r\n]+//g if defined $left;
      $right =~ s/[\r\n]+//g if defined $right;
      # 如果需要互换左右
      if($need_swap && defined $right) {
        $body = $right.$SEP.$left;
      } else {
        $body = defined $right ? $left.$SEP.$right : $left;
      }
      $line = $meta.$body;
    }
  }
  push @out,$line;
}

print join("\n",@out);
PERL
)"
}

move_to_trash() {
  local file="$1"
  local trash="$HOME/.Trash"
  [[ -e "$file" ]] || { echo "文件不存在: $file" >&2; return 1; }

  # 保留原文件名
  local name
  name=$(basename "$file")
  # 防止同名覆盖
  local target="$trash/$name"
  if [[ -e "$target" ]]; then
    local n=1
    while [[ -e "$trash/${name%.*}_$n.${name##*.}" ]]; do
      ((n++))
    done
    target="$trash/${name%.*}_$n.${name##*.}"
  fi

  mv "$file" "$target" && echo "已移入废纸篓: $target" || {
    echo "移入废纸篓失败: $file" >&2
    return 1
  }
}

ass_study_style_file() {
  local file="$1"

  [[ -f "$file" ]] || {
    echo "文件不存在: $file" >&2
    return 1
  }

  local encoding out tmp
  encoding="$(detect_encoding "$file")"
  out="${file%.ass}_study.ass"

  tmp="$(mktemp "${out}.XXXXXX")" || {
    echo "无法创建临时文件" >&2
    return 1
  }

  decode_to_utf8 "$file" "$encoding" |
    apply_study_style_stream |
    encode_from_utf8 "$encoding" "$tmp"

  if [[ ${PIPESTATUS[0]} -ne 0 || ${PIPESTATUS[1]} -ne 0 || ${PIPESTATUS[2]} -ne 0 ]]; then
    rm -f "$tmp"
    echo "生成失败: $file" >&2
    return 1
  fi

  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    echo "生成失败：输出为空" >&2
    return 1
  fi

  if ! mv "$tmp" "$out"; then
    rm -f "$tmp"
    echo "写入失败: $out" >&2
    return 1
  fi

  if [[ ! -s "$out" ]]; then
    echo "生成文件异常，保留原文件: $file" >&2
    return 1
  fi

  if move_to_trash "$file"; then
    echo "完成: $out"
    echo "原文件已移入废纸篓: $file"
  else
    echo "完成: $out"
    echo "原文件未删除，移入废纸篓失败: $file" >&2
  fi
}

ass_study_style_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo "目录不存在: $dir" >&2; return 1; }
  find "$dir" -type f -iname "*.ass" ! -iname "*_study.ass" -print0 |
  while IFS= read -r -d '' file; do
    ass_study_style_file "$file"
  done
}

case "$1" in
  file) ass_study_style_file "$2" ;;
  dir) ass_study_style_dir "$2" ;;
  *) usage; exit 1 ;;
esac