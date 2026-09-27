#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

git add -A
git commit -m "Polish Downloader repository and documentation" || true
git push origin main

echo
echo "已提交并推送到 GitHub。按回车关闭窗口。"
read -r
