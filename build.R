options(repos = c(CRAN = 'https://cran.rstudio.com'))

ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))

db = available.packages(type = 'source')
update.packages(ask = FALSE, checkBuilt = TRUE)

# only build packages that needs compilation and don't have binaries on CRAN
db2 = available.packages(type = 'binary')
pkgs = setdiff(rownames(db), rownames(db2))
pkgs = pkgs[db[pkgs, 'NeedsCompilation'] == 'yes']
pkgs = setdiff(pkgs, scan('ignore'))

# install xfun at least 0.2
if (tryCatch(packageVersion('xfun') < '0.2', error = function(e) TRUE)) {
  install.packages('xfun')
}

# render the homepage index.html
home = local({
  x = xfun::read_utf8('README.md')
  x[1] = paste0(x[1], '\n\n### Yihui Xie\n\n### ', Sys.Date(), '\n')
  xfun::write_utf8(x, 'index.Rmd'); on.exit(unlink('index.*'), add = TRUE)
  xfun::pkg_load2('knitr')
  knitr::rocco('index.Rmd', encoding = 'UTF-8')
  xfun::read_utf8('index.html')
})
system('git checkout gh-pages')

unlink(c('CNAME', 'src'), recursive = TRUE)
xfun::write_utf8(home, 'index.html')
writeLines(c(
  '/src/*  https://cran.rstudio.com/src/:splat',
  '/bin/windows/*  https://cran.rstudio.com/bin/windows/:splat'
), '_redirects')
unlink(dir, recursive = TRUE)

# delete binaries that have become available on CRAN, or of multiple versions of
# the same package
tgz = list.files(dir, '.+_.+[.]tgz$', full.names = TRUE)
tgz_name = gsub('_.*', '', basename(tgz))
file.remove(tgz[!(tgz_name %in% pkgs) | duplicated(tgz_name, fromLast = TRUE)])

# download source packages that have been updated on CRAN
if (file.exists(pkg_file <- file.path(dir, 'PACKAGES'))) {
  info = read.dcf(pkg_file, c('Package', 'Version'))
  pkgs = setdiff(pkgs, info[as.numeric_version(db[info[, 1], 'Version']) <= info[, 2], 1])
}
pkgs = intersect(pkgs, db[, 'Package'])

if (length(pkgs) == 0) q('no')

for (pkg in pkgs) xfun:::download_tarball(pkg, db)

failed = NULL
# build binary packages
for (pkg in list.files('.', '.+[.]tar[.]gz$')) {
  p = gsub('_.*$', '', pkg)
  # remove existing binary packages
  file.remove(list.files(dir, paste0('^', p, '_.+[.]tgz$'), full.names = TRUE))
  if (system2('autobrew', pkg) != 0) failed = c(failed, p)
}
if (length(failed)) warning('Failed to build packages: ', paste(failed, collapse = ' '))

dir.create(dir, recursive = TRUE, showWarnings = FALSE)

file.copy(list.files('.', '.+[.]tgz$'), dir, overwrite = TRUE)
unlink(c('*.tar.gz', '*.tgz'))

tools::write_PACKAGES(dir, type = 'mac.binary')

system2('ls', c('-lh', dir))
system('du -sh .')
