#!/usr/bin/env bash
# 构建单文件压缩版：index.html -> index.min.html
# 用法: ./build.sh [版本号]
set -euo pipefail
cd "$(dirname "$0")"

SRC=index.html
OUT=index.min.html
VER=${1:-$(date +%Y%m%d.%H%M)}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ 压缩 $SRC"
npx --yes html-minifier-terser \
  --collapse-whitespace --remove-comments --remove-redundant-attributes \
  --remove-empty-attributes --use-short-doctype --sort-attributes \
  --minify-css true --minify-js true \
  --output "$TMP/out.html" "$SRC"

# 压缩会删掉注释，版本信息在构建后插入
python3 - "$TMP/out.html" "$OUT" "$VER" <<'PY'
import sys, datetime
src, dst, ver = sys.argv[1:4]
s = open(src, encoding='utf-8').read()
note = '<!-- 云朵字工坊 v%s · built %s · 由 build.sh 从 index.html 生成，勿直接编辑本文件 -->' % (
    ver, datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))
assert '<head>' in s
s = s.replace('<head>', '<head>' + note, 1)
open(dst, 'w', encoding='utf-8').write(s)
print('  版本 %s' % ver)
PY

# 校验：内嵌字体与关键入口还在，且压缩后的 JS 仍能通过语法检查
python3 - "$OUT" "$TMP/app.js" <<'PY'
import sys, re
out, js = sys.argv[1:3]
s = open(out, encoding='utf-8').read()
m = re.search(r'<script>(.*)</script>', s, re.S)
assert m, '找不到 <script>'
open(js, 'w', encoding='utf-8').write(m.group(1))
for k in ['@font-face', 'CLHand', 'buildPDF', 'exportPNG', 'buildGeometry']:
    assert k in s, '缺少 ' + k
print('  内容校验通过')
PY
command -v node >/dev/null && node --check "$TMP/app.js" && echo '  语法校验通过'

ls -l "$SRC" "$OUT" | awk '{printf "  %-14s %s bytes\n", $9, $5}'
