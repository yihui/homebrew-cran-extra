options(repos = c(CRAN = 'https://cran.rstudio.com'))

ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))
# install brew dependencies
install_dep = function(pkg) {
  dep = c(
    RGtk2 = 'gtk+',
    RProtoBuf = 'protobuf',
    cairoDevice = 'cairo pkg-config gtk+',
    rgdal = 'gdal',
    rgeos = 'geos'
  )[pkg]
  if (!is.na(dep)) system(paste('brew install', dep))
}

# install xfun (from Github)
if (!requireNamespace('xfun', quietly = TRUE) || packageVersion('xfun') < '0.1.10') {
  source('https://install-github.me/yihui/xfun')
}

db = available.packages(type = 'source')

# make sure these packages' dependencies are installed (knitr is only for the homepage)
for (pkg in c('knitr', xfun:::pkg_dep(pkgs <- readLines('packages'), db))) {
  if (!xfun::loadable(pkg, new_session = TRUE)) {
    install_dep(pkg)
    if (!xfun::loadable(pkg, new_session = TRUE)) install.packages(pkg)
  }
}

# render the homepage index.html
home = local({
  x = xfun::read_utf8('README.md')
  x[1] = paste0(x[1], '\n\n### Yihui Xie\n\n### ', Sys.Date(), '\n')
  xfun::write_utf8(x, 'index.Rmd'); on.exit(unlink('index.*'), add = TRUE)
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

# delete binaries that were removed from the ./packages file, or of multiple
# versions of the same package
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

# build binary packages
for (pkg in list.files('.', '.+[.]tar[.]gz$')) {
  install_dep(p <- gsub('_.*$', '', pkg))
  # remove existing binary packages
  file.remove(list.files(dir, paste0('^', p, '_.+[.]tgz$'), full.names = TRUE))
  if (xfun::Rcmd(c('INSTALL', '--build', pkg)) != 0) stop(
    'Failed to build the package ', pkg
  )
}

dir.create(dir, recursive = TRUE, showWarnings = FALSE)

file.copy(list.files('.', '.+[.]tgz$'), dir, overwrite = TRUE)
unlink(c('*.tar.gz', '*.tgz'))

tools::write_PACKAGES(dir, type = 'mac.binary')

system2('ls', c('-lh', dir))
system('du -sh .')
