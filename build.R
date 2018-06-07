ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))

# install xfun (from Github)
if (!requireNamespace('xfun', quietly = TRUE) || packageVersion('xfun') < '0.1.10') {
  source('https://install-github.me/yihui/xfun')
}

# make sure these packages' dependencies are installed
for (pkg in pkgs <- readLines('packages')) {
  if (!xfun::loadable(pkg, new_session = TRUE)) install.packages(pkg)
}

system('git checkout gh-pages')
# download source packages that have been updated on CRAN
db = available.packages(type = 'source')
if (file.exists(pkg_file <- file.path(dir, 'PACKAGES'))) {
  info = read.dcf(pkg_file, c('Package', 'Version'))
  pkgs = setdiff(pkgs, info[as.numeric_version(db[info[, 1], 'Version']) <= info[, 2], 1])
}
pkgs = intersect(pkgs, db[, 'Package'])

if (length(pkgs) == 0) q('no')

for (pkg in pkgs) xfun:::download_tarball(pkg, db)

# build binary packages
for (pkg in list.files('.', '.+[.]tar[.]gz$')) {
  if (xfun::Rcmd(c('INSTALL', '--build', pkg)) != 0) stop(
    'Failed to build the package ', pkg
  )
}

dir.create(c(dir, 'src/contrib'), recursive = TRUE, showWarnings = FALSE)
file.create('src/contrib/PACKAGES')

file.copy(list.files('.', '.+[.]tgz$'), dir, overwrite = TRUE)
unlink(c('*.tar.gz', '*.tgz'))

tools::write_PACKAGES(dir, type = 'mac.binary')
