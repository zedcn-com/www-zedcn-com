hexo clean
hexo generate
rsync -av --delete --exclude=CNAME public/ docs/