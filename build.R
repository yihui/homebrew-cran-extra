ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))
dir.create(dir, recursive = TRUE, showWarnings = FALSE)

# install xfun (from Github)
if (!requireNamespace('xfun') || packageVersion('xfun') < '0.1.10') {
  source('https://install-github.me/yihui/xfun')
}

owd = setwd(tempdir())

# make sure these packages' dependencies are installed
for (pkg in pkgs <- readLines('packages')) {
  if (!xfun::loadable(pkg, new_session = TRUE)) install.packages(pkg)
}

# download source packages that have been updated on CRAN
if (file.exists(file.path(owd, dir, 'PACKAGES'))) {
  old = old.packages(.libPaths()[1], checkBuilt = TRUE, type = 'source')
  colnames(old)[5] = 'Version' # ReposVer
} else {
  old = available.packages(type = 'source')  # no binaries have been built
}
if (!is.matrix(old)) q('no')

for (pkg in intersect(pkgs, old[, 'Package'])) xfun:::download_tarball(pkg, old)
if (is.null(pkg)) q('no')

# build binary packages
for (pkg in list.files('.', '.+[.]tar[.].gz$')) {
  if (xfun::Rcmd(c('INSTALL', '--build', pkg)) != 0) stop(
    'Failed to build the package ', pkg
  )
}
file.copy(list.files('.', '.+[.]tgz$'), file.path(owd, dir), overwrite = TRUE)
setwd(owd)

tools::write_PACKAGES(dir, type = 'mac.binary')
