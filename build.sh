#!/usr/bin/env bash
# 构建交付文件：src/index.html（源码，无 base64）+ 内嵌字体 -> index.html / index.min.html
# 源码不带 base64 字体，便于阅读与 AI 检索；改功能请编辑 src/index.html 后运行本脚本
# 用法: ./build.sh [版本号]
set -euo pipefail
cd "$(dirname "$0")"

SRC=src/index.html
FONT=xumin字体.woff2
NOTOFONT=NotoSans-Regular.woff2
OUT=index.html
OUTMIN=index.min.html
VER=${1:-$(date +%Y%m%d.%H%M)}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ 注入字体生成 $OUT"
python3 - "$SRC" "$FONT" "$NOTOFONT" "$TMP/full.html" <<'PY'
import sys, base64
src, font, notofont, out = sys.argv[1:5]
s = open(src, encoding='utf-8').read()
# 只替换 CSS 里的 data-URI 占位符；JS 开发态分支里的占位符字面量必须保留
for path, ph in ((font, '__CLHAND_B64__'), (notofont, '__NOTO_B64__')):
    holder = 'base64,' + ph
    assert holder in s, 'src 里找不到字体占位符 ' + holder
    s = s.replace(holder, 'base64,' + base64.b64encode(open(path, 'rb').read()).decode(), 1)
assert '<head>' in s
s = s.replace('<head>', '<head><!-- 本文件由 build.sh 生成（内嵌 base64 字体），改代码请编辑 src/index.html -->', 1)
open(out, 'w', encoding='utf-8').write(s)
PY
cp "$TMP/full.html" "$OUT"

echo "→ 压缩生成 $OUTMIN"
npx --yes html-minifier-terser \
  --collapse-whitespace --remove-comments --remove-redundant-attributes \
  --remove-empty-attributes --use-short-doctype --sort-attributes \
  --minify-css true --minify-js true \
  --output "$TMP/out.html" "$TMP/full.html"

python3 - "$TMP/out.html" "$OUTMIN" "$VER" <<'PY'
import sys, datetime
src, dst, ver = sys.argv[1:4]
s = open(src, encoding='utf-8').read()
note = '<!-- 云朵字工坊 v%s · built %s · 由 build.sh 从 src/index.html 生成，勿直接编辑本文件 -->' % (
    ver, datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))
assert '<head>' in s
s = s.replace('<head>', '<head>' + note, 1)
open(dst, 'w', encoding='utf-8').write(s)
print('  版本 %s' % ver)
PY

# 校验：字体已内嵌、占位符已替换、关键入口还在，压缩后的 JS 能通过语法检查
python3 - "$OUT" "$OUTMIN" "$TMP/app.js" <<'PY'
import sys, re
full, out, js = sys.argv[1:4]
sfull = open(full, encoding='utf-8').read()
sout = open(out, encoding='utf-8').read()
for name, s in (('index.html', sfull), ('index.min.html', sout)):
    assert '@font-face' in s and 'CLHand' in s, name + ' 缺少内嵌手写体'
    assert 'CLNoto' in s, name + ' 缺少内嵌思源黑体'
    for ph in ('__CLHAND_B64__', '__NOTO_B64__'):
        assert 'base64,' + ph not in s, name + ' 字体占位符 ' + ph + ' 未被替换'
        assert ph in s, name + ' 缺少开发态字体分支 ' + ph
    assert re.search(r'<script>.*</script>', s, re.S), name + ' 找不到 <script>'
for k in ['buildPDF', 'exportPNG', 'buildGeometry']:
    assert k in sfull, '缺少 ' + k
open(js, 'w', encoding='utf-8').write(re.search(r'<script>(.*)</script>', sout, re.S).group(1))
print('  内容校验通过')
PY
command -v node >/dev/null && node --check "$TMP/app.js" && echo '  语法校验通过'

ls -l "$SRC" "$OUT" "$OUTMIN" | awk '{printf "  %-16s %s bytes\n", $9, $5}'
