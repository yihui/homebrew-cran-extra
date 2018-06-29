options(repos = c(CRAN = 'https://cran.rstudio.com'))

ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))
# no openmp support
if (!file.exists('~/.R/Makevars'))
  writeLines(c('SHLIB_OPENMP_CFLAGS=', 'SHLIB_OPENMP_CXXFLAGS='), '~/.R/Makevars')

# install brew dependencies that are not available in r-hub/sysreqsdb yet
install_dep = function(pkg) {
  dep = c(
    glpkAPI = 'glpk',
    qtbase = 'qt',
    RDieHarder = 'dieharder',
    Rgnuplot = 'gnuplot',
    RQuantLib = 'quantlib',
    RcppMeCab = 'mecab',
    RGtk2Extras = 'gtk+',
    gWidgetsRGtk2 = 'gtk+',
    Rglpk = 'glpk'
  )[pkg]
  if (!is.na(dep)) system(paste('brew install', dep, '|| brew upgrade', dep))
}

db = available.packages(type = 'source')
update.packages(ask = FALSE, checkBuilt = TRUE)

# only build packages that needs compilation and don't have binaries on CRAN
db2 = available.packages(type = 'binary')
pkgs = setdiff(rownames(db), rownames(db2))
pkgs = pkgs[db[pkgs, 'NeedsCompilation'] == 'yes']
pkgs = setdiff(pkgs, readLines('ignore'))

# manually specify a subset of packages to be built
if (file.exists('subset')) pkgs = intersect(pkgs, readLines('subset'))

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

# delete binaries that have become available on CRAN, or of multiple versions of
# the same package
if (!file.exists('subset')) {
  tgz = list.files(dir, '.+_.+[.]tgz$', full.names = TRUE)
  tgz_name = gsub('_.*', '', basename(tgz))
  file.remove(tgz[!(tgz_name %in% pkgs) | duplicated(tgz_name, fromLast = TRUE)])
}

# download source packages that have been updated on CRAN
if (file.exists(pkg_file <- file.path(dir, 'PACKAGES'))) {
  info = read.dcf(pkg_file, c('Package', 'Version'))
  pkgs = setdiff(pkgs, info[as.numeric_version(db[info[, 1], 'Version']) <= info[, 2], 1])
}
pkgs = intersect(pkgs, db[, 'Package'])

if (length(pkgs) == 0) q('no')

pkg_all = c(rownames(db), rownames(installed.packages()))
for (pkg in pkgs) {
  # dependency not available on CRAN
  if (!all(xfun:::pkg_dep(pkg, db) %in% pkg_all)) next
  xfun:::download_tarball(pkg, db)
}
srcs = list.files('.', '.+[.]tar[.]gz$')
pkgs = gsub('_.*$', '', srcs)
names(pkgs) = srcs

failed = NULL
# build binary packages
build_one = function(pkg) {
  # remove existing binary packages
  file.remove(list.files(dir, paste0('^', pkg, '_.+[.]tgz$'), full.names = TRUE))
  # skip if already built
  if (length(list.files('.', paste0('^', pkg, '_.+[.]tgz$')))) return()
  for (p in intersect(pkgs, deps <- xfun:::pkg_dep(pkg, db))) build_one(pkgs[pkgs == p])
  message('Building ', pkg)
  install_dep(pkg)
  install.packages(deps, repos = 'https://macos.rbind.org')
  # autobrew assumes static linking, which may be difficult or impossible for
  # some packages (e.g., RGtk2), so we retry R CMD INSTALL --build instead if
  # autobrew fails, but this means we will rely on dynamic linking
  if (system2('autobrew', names(pkg)) == 0) {
    xfun::Rcmd(c('INSTALL', paste0(pkg, '_*.tgz')))
  } else if (xfun::Rcmd(c('INSTALL', '--build', names(pkg))) != 0)
    failed <<- c(failed, pkg)
}
for (i in seq_along(pkgs)) build_one(pkgs[i])

if (length(failed)) warning('Failed to build packages: ', paste(failed, collapse = ' '))

dir.create(dir, recursive = TRUE, showWarnings = FALSE)

file.copy(list.files('.', '.+[.]tgz$'), dir, overwrite = TRUE)
unlink(c('*.tar.gz', '*.tgz'))

tools::write_PACKAGES(dir, type = 'mac.binary')

system2('ls', c('-lh', dir))
system('du -sh .')
