npx hexo clean
npx hexo generate
rsync -av --delete --exclude=CNAME public/ docs/
git add *
git stage *
datetime=`date +"%Y-%m-%dT%H:%M:%S"`
git commit -m "rebuild at $datetime"