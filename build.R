options(repos = c(CRAN = 'https://cran.rstudio.com'))

ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))
# install brew dependencies
install_dep = function(pkg) {
  dep = c(
    RGtk2 = 'gtk+',
    RProtoBuf = 'protobuf',
    cairoDevice = 'cairo pkg-config gtk+'
  )[pkg]
  if (!is.na(dep)) system(paste('brew install', dep))
}

# install xfun (from Github)
if (!requireNamespace('xfun', quietly = TRUE) || packageVersion('xfun') < '0.1.10') {
  source('https://install-github.me/yihui/xfun')
}

db = available.packages(type = 'source')

# make sure these packages' dependencies are installed
for (pkg in xfun:::pkg_dep(pkgs <- readLines('packages'), db)) {
  if (!xfun::loadable(pkg, new_session = TRUE)) {
    install_dep(pkg)
    if (!xfun::loadable(pkg, new_session = TRUE)) install.packages(pkg)
  }
}

system('git checkout gh-pages')

unlink(c('CNAME', 'src'), recursive = TRUE)
writeLines(c(
  '/src/*  https://cran.rstudio.com/src/:splat',
  '/bin/windows/*  https://cran.rstudio.com/bin/windows/:splat'
), '_redirects')

# delete binaries that were removed from the ./packages file
tgz = list.files(dir, '.+_.+[.]tgz$', full.names = TRUE)
file.remove(tgz[!(gsub('_.*', '', basename(tgz)) %in% pkgs)])

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
  install_dep(gsub('_.*$', '', pkg))
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
