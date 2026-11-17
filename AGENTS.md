# Cloud Letter Maker — AI 协作须知

- **源码只有一个：`src/index.html`**（不含 base64 字体，约 105KB，纯文本可读）。改任何功能、样式、脚本都改这个文件。
- `index.html` 和 `index.min.html` 是 `./build.sh` 生成的**交付产物**，内嵌约 27KB 的 base64 字体行。**不要读取也不要编辑这两个文件**——读取只会浪费大量 token，编辑会在下次构建时被覆盖。
- 改完源码后运行 `./build.sh` 重新生成两个交付文件（首次运行需要联网拉取 `html-minifier-terser`）。
- 字体文件 `xumin字体.TTF` 是手写体源文件，构建时以 base64 注入 `src/index.html` 里的 `__CLHAND_B64__` 占位符。换字体 = 替换该 TTF 并重跑构建。
