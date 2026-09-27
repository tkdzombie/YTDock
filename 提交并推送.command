#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

git add -A
git commit -m "Release Downloader 2.0 public downloader" || true
git push origin main

echo
echo "已提交并推送到 GitHub。按回车关闭窗口。"
read -r
