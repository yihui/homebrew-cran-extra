install.packages('xfun')

db = available.packages(type = 'source')
update.packages(checkBuilt = TRUE, ask = FALSE)

ver = paste(unlist(getRversion())[1:2], collapse = '.')  # version x.y
dir = file.path('bin/macosx/contrib', ver)

# no openmp support
cat('\nSHLIB_OPENMP_CFLAGS=\nSHLIB_OPENMP_CXXFLAGS=\n', file = '~/.R/Makevars', append = TRUE)

# install brew dependencies that are not available in r-hub/sysreqsdb yet
sysreqsdb = list(
  glpkAPI = 'glpk',
  Rglpk = 'glpk',
  rDEA = 'glpk',
  qtbase = 'qt',
  Rhpc = 'open-mpi',
  RDieHarder = 'dieharder',
  Rgnuplot = 'gnuplot',
  RQuantLib = 'quantlib',
  RcppMeCab = 'mecab',
  RGtk2 = c('gtk+', 'gobject-introspection'),
  Rmpi = 'open-mpi',
  cairoDevice = c('gtk+', 'cairo'),
  rgl = 'freetype',
  libstableR = 'gsl'
)

retry = function(expr, times = 3) {
  for (i in seq_len(times)) {
    if (!inherits(res <- try(expr, silent = TRUE), 'try-error')) return(res)
    Sys.sleep(5)
  }
}

# query Homebrew dependencies for an R package
brew_dep = function(pkg) {
  v = sysreqsdb[[pkg]]
  if (inherits(v, 'AsIs')) return(v)
  u = sprintf('https://sysreqs.r-hub.io/pkg/%s/osx-x86_64-clang', pkg)
  x = retry(readLines(u, warn = FALSE))
  x = gsub('^\\s*\\[|\\]\\s*$', '', x)
  x = unlist(strsplit(gsub('"', '', x), ','))
  x = setdiff(x, 'null')
  if (length(x))
    message('Package ', pkg, ' requires Homebrew packages: ', paste(x, collapse = ' '))
  sysreqsdb[[pkg]] <<- I(unique(c(v, x)))
  x
}
brew_deps = function(pkgs) {
  unlist(lapply(pkgs, brew_dep))
}

install_dep = function(pkg) {
  dep = brew_deps(c(pkg, xfun:::pkg_dep(pkg, db, recursive = TRUE)))
  if (length(dep) == 0) return()
  dep = paste(dep, collapse = ' ')
  if (dep != '') system(paste('brew install', dep))
}

# only build packages that needs compilation and don't have binaries on CRAN
db2 = available.packages(type = 'binary')
pkgs = setdiff(rownames(db), rownames(db2))
pkgs = pkgs[db[pkgs, 'NeedsCompilation'] == 'yes']
pkgs = setdiff(pkgs, readLines('ignore'))  # exclude pkgs that I'm unable to build

# manually specify a subset of packages to be built
if (file.exists('subset')) pkgs = intersect(pkgs, readLines('subset'))
# extra packages that must be built
if (file.exists('extra')) pkgs = c(pkgs, readLines('extra'))

# set an env var to decide which subset of pkgs to build, e.g., "0, 0.5", "0.1, 8.7"
if (!is.na(i <- Sys.getenv('CRAN_BUILD_SUBSET', NA))) {
  n = length(pkgs)
  i = as.numeric(strsplit(i, ',\\s*')[[1]]) * n
  i = seq(max(1, floor(i[1])), min(n, ceiling(i[2])))
  pkgs = pkgs[i]
}

# render the homepage index.html
home = local({
  x = xfun::read_utf8('README.md')
  x[1] = paste0(x[1], '\n\n### Yihui Xie\n\n### ', Sys.Date(), '\n')
  xfun::write_utf8(x, 'index.Rmd')
  on.exit(file.remove(list.files('.', '^index[.][a-z]+$', ignore.case = TRUE)), add = TRUE)
  xfun::pkg_load2('knitr')
  knitr::rocco('index.Rmd')
  xfun::read_utf8('index.html')
})
system('git checkout gh-pages')

unlink(c('CNAME', 'src'), recursive = TRUE)
xfun::write_utf8(home, 'index.html')
writeLines(c(
  'https://macos.rbind.org/*  https://macos.rbind.io/:splat  301!',
  '/src/*  https://cran.rstudio.com/src/:splat',
  '/bin/windows/*  https://cran.rstudio.com/bin/windows/:splat'
), '_redirects')

# R 4.0 changed the package path (no longer use el-capitan in the path)
if (dir.exists(d4 <- 'bin/macosx/el-capitan/contrib')) {
  unlink(dir, recursive = TRUE)
  file.rename(d4, dirname(dir))
}

# when a new version of R appears, move the old binary packages to the new dir
if (!dir.exists(dir)) xfun::in_dir(dirname(dir), {
  if ((n <- length(vers <- list.files('.', '^\\d+[.]\\d+$'))) >= 1) {
    unlink(vers[seq_len(n - 1)], recursive = TRUE)
    file.rename(vers[n], ver)
  }
})
dir.create(dir, recursive = TRUE, showWarnings = FALSE)

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
  info = info[info[, 1] %in% rownames(db), , drop = FALSE]  # packages may be archived
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
  # the brew formula libffi is keg-only; needs to inform pkg-config
  if ('gtk+' %in% sysreqsdb[[pkg]]) {
    env = Sys.getenv('PKG_CONFIG_PATH')
    on.exit(Sys.setenv(PKG_CONFIG_PATH = env), add = TRUE)
    Sys.setenv(PKG_CONFIG_PATH = "/usr/local/opt/libffi/lib/pkgconfig")
  }
  # remove existing binary packages
  file.remove(list.files(dir, paste0('^', pkg, '_.+[.]tgz$'), full.names = TRUE))
  # skip if already built
  if (length(list.files('.', paste0('^', pkg, '_.+[.]tgz$')))) return()
  for (p in intersect(pkgs, deps <- xfun:::pkg_dep(pkg, db))) build_one(pkgs[pkgs == p])
  install_dep(pkg)
  for (p in deps) {
    if (xfun::loadable(p)) next
    install.packages(p, repos = c(getOption('repos'), 'https://macos.rbind.io'))
  }
  # autobrew assumes static linking, which may be difficult or impossible for
  # some packages (e.g., RGtk2), so we retry R CMD INSTALL --build instead if
  # autobrew fails, but this means we will rely on dynamic linking
  if (system2('autobrew', names(pkg)) == 0) {
    xfun::Rcmd(c('INSTALL', file.path('binaries', sub('[.]tar[.]gz$', '.tgz', names(pkg)))))
  } else if (xfun::Rcmd(c('INSTALL', '--build', names(pkg))) != 0)
    failed <<- c(failed, pkg)
}
t0 = Sys.time()
for (i in seq_along(pkgs)) {
  message('Building ', pkgs[i], ' (', i, '/', length(pkgs), ')')
  build_one(pkgs[i])
  # give up the current job to avoid timeout on Github Action this time; we can
  # continue the rest next time
  if (difftime(Sys.time(), t0, units = 'mins') > 300) break
}

if (length(failed)) warning('Failed to build packages: ', paste(failed, collapse = ' '))

for (d in c('.', './binaries')) {
  file.copy(list.files(d, '.+[.]tgz$', full.names = TRUE), dir, overwrite = TRUE)
}
unlink(c('*.tar.gz', '*.tgz', '_AUTOBREW_BUILD', d), recursive = TRUE)
unlink(c('PACKAGES*', 'index.md'))

tools::write_PACKAGES(dir, type = 'mac.binary')
saveRDS(sysreqsdb, 'bin/macosx/sysreqsdb.rds')

system2('ls', c('-lh', dir))
system('du -sh .')
