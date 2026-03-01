# ① 下载指定时间段（最大分辨率 + H.264 + mp4）

# 你要：

# H.264（avc1）

# mp4 容器

# 最大分辨率

# 时间段下载

# 不重新编码（快速模式）

# 推荐 yt-dlp + ffmpeg 组合
# start="3"
# end="5"

# "$yt_dlp" \
#   -f "bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
#   --download-sections "*${start}-${end}" \
#   --force-keyframes-at-cuts \
#   -o "segment.%(ext)s" \
#   "$url"

# 说明：

# bestvideo[vcodec^=avc1] → H.264
# ext=mp4                → mp4 容器
# --download-sections    → 指定时间段
# --force-keyframes-at-cuts → 尝试在边界插入关键帧

# ⚠ 注意：这里仍然是关键帧对齐，不是精确裁剪。

# ② 如何知道实际关键帧时间

# 关键帧不一定在整秒。

# 你可以用 ffprobe：

# ffprobe \
#   -select_streams v:0 \
#   -show_frames \
#   -show_entries frame=pkt_pts_time,key_frame \
#   -of csv \
#   segment.mp4 | grep ",1"

# 输出类似：

# 2.000000,1
# 4.000000,1
# 6.000000,1

# 如果你想找：

# 下载视频的第一个关键帧时间

# 可以：

# ffprobe -v error \
#   -select_streams v:0 \
#   -skip_frame nokey \
#   -show_entries frame=pkt_pts_time \
#   -of default=nw=1:nk=1 \
#   segment.mp4 | head -n 1

# 这就是你真实的起始时间。

# ③ 如何把下载的视频解码

# 如果只是裁剪，其实不需要“显式解码”。

# ffmpeg 会自动解码。

# 但如果你想完全解码为无压缩视频（学习用途）：

# ffmpeg -i segment.mp4 -c:v rawvideo -pix_fmt yuv420p decoded.yuv

# ⚠ 这个文件会巨大，不建议实际使用。

# ④ 精确裁剪（真正的核心）

# 关键点：

# -ss 放在 -i 后面 → 精确裁剪（会解码）
# -ss 放在 -i 前面 → 快速裁剪（关键帧对齐）

# 你现在要的是精确裁剪：

# real_start="2"   # 假设关键帧是 2 秒
# want_start="3"
# want_end="5"

# trim_start=$(echo "$want_start - $real_start" | bc)

# duration=$(echo "$want_end - $want_start" | bc)

# ffmpeg \
#   -i segment.mp4 \
#   -ss "$trim_start" \
#   -t "$duration" \
#   -c:v libx264 \
#   -c:a aac \
#   final.mp4

# 这一步会：

# 解码

# 精确裁剪

# 重新编码

# ⑤ 如何重新编码

# 标准 H.264 编码：

# ffmpeg -i input.mp4 \
#   -c:v libx264 \
#   -preset slow \
#   -crf 18 \
#   -c:a aac \
#   output.mp4

# 关键参数：

# crf 18  → 高质量
# crf 23  → 默认
# crf 28  → 更小体积
# ⑥ 除下载外，是否都在本地？

# 是的。

# 步骤	是否联网
# yt-dlp 下载	✅ 需要
# ffprobe	❌ 本地
# ffmpeg 裁剪	❌ 本地
# 重新编码	❌ 本地

# 所以你只在第一步联网。

# 后面全部本地操作。

# 🔥 你现在理解的流程是对的

# 真正专业流程是：

# 1. 网络快速下载（关键帧对齐）
# 2. 本地解析关键帧时间
# 3. 计算偏移
# 4. 本地精确裁剪
# 5. 本地重新编码

# 这就是影视行业常见的 workflow。

# 💡 你下一个可以研究的点

# 你可以试试：

# ffprobe -show_packets

# 看 GOP 结构。

# 你会看到：

# I frame
# P frame
# B frame

# 你会真正理解压缩机制。

# 如果你愿意，我可以下一步带你：

# 自动计算真实起始关键帧

# 自动算偏移

# 自动精确裁剪

# 我们可以把它做成一个完整模块。

# 你现在的脚本架构完全有能力支持它。