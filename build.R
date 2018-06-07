options(repos = c(CRAN = 'https://cran.rstudio.com'))

ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))
# install brew dependencies
install_dep = function(pkg) {
  dep = c(
    RGtk2 = 'gtk+',
    RProtoBuf = 'protobuf'
  )[pkg]
  if (!is.na(dep)) system(paste('brew install', dep))
}

# install xfun (from Github)
if (!requireNamespace('xfun', quietly = TRUE) || packageVersion('xfun') < '0.1.10') {
  source('https://install-github.me/yihui/xfun')
}

# TODO: remove this when RGtk2 > 2.20.34 is on CRAN
if (!xfun::loadable('devtools', new_session = TRUE)) install.packages('devtools')
if (!xfun::loadable('RGtk2', new_session = TRUE)) {
  install_dep('RGtk2')
  devtools::install_github('lawremi/RGtk2/RGtk2')
}

# make sure these packages' dependencies are installed
for (pkg in pkgs <- readLines('packages')) {
  if (!xfun::loadable(pkg, new_session = TRUE)) {
    install_dep(pkg); install.packages(pkg)
  }
}

system('git checkout gh-pages')

# delete binaries that were removed from the ./packages file
tgz = list.files(dir, '.+_.+[.]tgz$', full.names = TRUE)
file.remove(tgz[!(gsub('_.*', '', basename(tgz)) %in% pkgs)])

# download source packages that have been updated on CRAN
db = available.packages(type = 'source')
if (file.exists(pkg_file <- file.path(dir, 'PACKAGES'))) {
  info = read.dcf(pkg_file, c('Package', 'Version'))
  pkgs = setdiff(pkgs, info[as.numeric_version(db[info[, 1], 'Version']) <= info[, 2], 1])
}
pkgs = intersect(pkgs, db[, 'Package'])

if (length(pkgs) == 0) q('no')

# TODO: remove this when RGtk2 > 2.20.34 is on CRAN
if ('RGtk2' %in% pkgs && db['RGtk2', 'Version'] == '2.20.34') {
  system('brew install gtk+')
  system('git clone --depth=1 https://github.com/lawremi/RGtk2.git')
  system('R CMD build RGtk2/RGtk2')
  unlink('RGtk2', recursive = TRUE)
  pkgs = setdiff(pkgs, 'RGtk2')
}

for (pkg in pkgs) xfun:::download_tarball(pkg, db)

# build binary packages
for (pkg in list.files('.', '.+[.]tar[.]gz$')) {
  install_dep(gsub('_.*$', '', pkg))
  if (xfun::Rcmd(c('INSTALL', '--build', pkg)) != 0) stop(
    'Failed to build the package ', pkg
  )
}

dir.create(dir, recursive = TRUE, showWarnings = FALSE)
dir.create('src/contrib', recursive = TRUE, showWarnings = FALSE)
file.create('src/contrib/PACKAGES')

file.copy(list.files('.', '.+[.]tgz$'), dir, overwrite = TRUE)
unlink(c('*.tar.gz', '*.tgz'))

tools::write_PACKAGES(dir, type = 'mac.binary')

system2('ls', c('-lh', dir))
system('du -sh .')
