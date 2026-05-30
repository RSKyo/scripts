import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

// node rename-media.js ./movies --dry
// node rename-media.js ./movies

const DRY_RUN = process.argv.includes('--dry');

function probe(file) {
  try {
    const cmd = `ffprobe -v quiet -print_format json -show_streams "${file}"`;
    return JSON.parse(execSync(cmd).toString());
  } catch {
    return null;
  }
}

function cleanBase(base) {
  return base
    .replace(/\[.*?\]/g, '') // 去中文标签
    .replace(/(10bit|2Audio|3Audio|4Audio)/gi, '')
    .replace(/\.+/g, '.')
    .trim();
}

function skipFile(name) {
  return (
    name.startsWith('.') ||
    name.includes('2in1') ||
    name.includes('合集') ||
    name.match(/S\d+/i)
  );
}

function detectEdition(base) {
  if (base.includes('REMUX')) return 'REMUX';
  if (base.match(/EXTENDED/i)) return 'Extended';
  if (base.match(/THEATRICAL/i)) return 'Theatrical';
  return null;
}

function detectSource(base) {
  if (base.includes('BluRay')) return 'BluRay';
  if (base.includes('WEB-DL')) return 'WEB-DL';
  return null;
}

function getVideo(streams) {
  const v = streams.find(s => s.codec_type === 'video');
  if (!v) return {};

  let codec =
    v.codec_name === 'hevc' ? 'x265' :
    v.codec_name === 'h264' ? 'x264' : null;

  let hdr = null;
  if (v.color_transfer?.includes('2084')) hdr = 'HDR';

  return { codec, hdr, height: v.height };
}

function getAudio(streams) {
  const a = streams.find(s => s.codec_type === 'audio');
  if (!a) return {};

  let codec = null;

  if (a.codec_name === 'truehd') codec = 'TrueHD';
  else if (a.codec_name === 'dts') {
    if (a.profile?.includes('MA')) codec = 'DTS-HD.MA';
    else codec = 'DTS';
  }
  else if (a.codec_name === 'eac3') codec = 'DDP';
  else codec = a.codec_name;

  let channels = a.channels === 8 ? '7.1' :
                 a.channels === 6 ? '5.1' : '';

  return { codec, channels };
}

function detectAtmos(base) {
  return base.includes('Atmos') ? 'Atmos' : null;
}

function detectDV(base) {
  return /DV|DoVi/i.test(base);
}

function buildName(file, info, baseRaw) {
  const base = cleanBase(baseRaw);

  const parts = base.split('.');
  const year = parts.find(p => /^\d{4}$/.test(p));
  const title = parts.slice(0, parts.indexOf(year)).join('.');

  const resolution =
    info.video.height >= 2000 ? '2160p' :
    info.video.height >= 1000 ? '1080p' : null;

  const edition = detectEdition(baseRaw);
  const source = detectSource(baseRaw);

  const video = baseRaw.includes('AVC') ? 'AVC' : info.video.codec;

  const dv = detectDV(baseRaw);
  const hdr = dv ? 'DV' : info.video.hdr;

  const atmos = detectAtmos(baseRaw);

  const audio = info.audio.codec;
  const channels = info.audio.channels;

  return [
    title,
    year,
    resolution,
    source,
    edition,
    video,
    hdr,
    atmos,
    audio,
    channels
  ]
    .filter(Boolean)
    .join('.') + '.mkv';
}

function main(dir) {
  const files = fs.readdirSync(dir).filter(f =>
    f.endsWith('.mkv') && !f.startsWith('.')
  );

  for (const f of files) {
    if (skipFile(f)) continue;

    const full = path.join(dir, f);
    const data = probe(full);
    if (!data) continue;

    const video = getVideo(data.streams);
    const audio = getAudio(data.streams);

    const newName = buildName(f, { video, audio }, f);

    console.log(`\n${f}`);
    console.log(`→ ${newName}`);

    if (!DRY_RUN && f !== newName) {
      fs.renameSync(full, path.join(dir, newName));
    }
  }
}

main(process.argv[2] || '.');