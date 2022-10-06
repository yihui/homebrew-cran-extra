# TODO: use CRAN version of xfun (>= 0.26)
install.packages('remotes')
remotes::install_github('yihui/xfun')

db = available.packages(type = 'source')
all_pkgs = rownames(db)

ver = paste(unlist(getRversion())[1:2], collapse = '.')  # version x.y
dir = file.path('bin/macosx/contrib', ver)

# no openmp support
cat('\nSHLIB_OPENMP_CFLAGS=\nSHLIB_OPENMP_CXXFLAGS=\n', file = '~/.R/Makevars', append = TRUE)

# only build packages that needs compilation and don't have binaries on CRAN
db2 = available.packages(type = 'binary')
pkgs = setdiff(all_pkgs, rownames(db2))
pkgs = pkgs[db[pkgs, 'NeedsCompilation'] == 'yes']
pkgs = setdiff(pkgs, readLines('ignore'))  # exclude pkgs that I'm unable to build

# manually specify a subset of packages to be built
if (file.exists('subset')) pkgs = intersect(pkgs, readLines('subset'))
# extra packages that must be built
pkgs = c(if (file.exists('extra')) readLines('extra'), if (FALSE) pkgs)
# NOTE: originally we tried to build all packages that don't have binaries on
# CRAN, but this made the project burdensome to maintain; now we only build
# these 'extra' packages. If any volunteer wants to pick up the original
# project, please feel free to let me know and I can transfer it to you.

# set an env var to decide which subset of pkgs to build, e.g., "0, 0.5", "0.1, 8.7"
if (!is.na(i <- Sys.getenv('CRAN_BUILD_SUBSET', NA))) {
  n = length(pkgs)
  i = as.numeric(strsplit(i, ',\\s*')[[1]]) * n
  i = seq(max(1, floor(i[1])), min(n, ceiling(i[2])))
  pkgs = pkgs[i]
}

home = xfun::read_utf8('README.md')
system('git checkout gh-pages')

unlink(c('CNAME', 'src'), recursive = TRUE)
writeLines(c(
  'https://macos.rbind.org/*  https://macos.rbind.io/:splat  301!',
  '/src/*  https://cran.rstudio.com/src/:splat',
  '/bin/windows/*  https://cran.rstudio.com/bin/windows/:splat'
), '_redirects')

sysreqsdb = if (file.exists(sysdb <- 'bin/macosx/sysreqsdb.rds')) readRDS(sysdb) else list()

# install brew dependencies that are not available in r-hub/sysreqsdb yet
sysreqsdb2 = list(
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
  RSclient = 'openssl',
  Rmpi = 'open-mpi',
  cairoDevice = c('gtk+', 'cairo'),
  rgl = c('freetype', 'freeglut'),
  rrd = 'rrdtool',
  libstableR = 'gsl'
)

base_pkgs = xfun::base_pkgs()

# query Homebrew dependencies for an R package and save them
brew_dep = function(pkg) {
  if (pkg %in% base_pkgs) return()
  d = sysreqsdb[[pkg]]
  v = xfun::attr(d, 'Version')
  v2 = if (pkg %in% all_pkgs) db[pkg, 'Version'] else NA
  # return if dependency exists and package version hasn't changed
  if (!is.null(d) && identical(v, v2)) return(d)
  x = unique(c(xfun:::brew_dep(pkg), sysreqsdb2[[pkg]]))
  attr(x, 'Version') = v2
  sysreqsdb[[pkg]] <<- x
}

for (i in unique(c(pkgs, .packages(TRUE), names(sysreqsdb)))) sysreqsdb[[i]] = brew_dep(i)

# refresh the db for a random subset of all CRAN packages (can't do all because
# querying dependencies is time-consuming)
sample_max = function(x, n) {
  sample(x, min(n, length(x)))
}
# packages for which we haven't queried dependencies yet
for (i in sample_max(setdiff(all_pkgs, names(sysreqsdb)), 5000)) {
  sysreqsdb[[i]] = brew_dep(i)
}
# remove packages that are no longer on CRAN
# for (i in setdiff(names(sysreqsdb), all_pkgs)) sysreqsdb[[i]] = NULL

brew_deps = function(pkgs) {
  unlist(lapply(unique(pkgs), brew_dep))
}

install_deps = function(pkgs) {
  dep = brew_deps(c(pkgs, xfun:::pkg_dep(pkgs, db, recursive = TRUE), .packages(TRUE)))
  dep = setdiff(dep, 'TODO')  # not sure how it came in
  if (length(dep) == 0) return()
  dep = paste(unique(dep), collapse = ' ')
  if (dep == '') return()
  message('Installing Homebrew dependencies: ', dep)
  system(paste('brew install', dep))
}

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

xfun:::check_built(dir, dry_run = FALSE)

install_extra = function(p) {
  install.packages(p, repos = c(paste0('file://', getwd()), getOption('repos')), type = 'mac.binary')
}
for (i in setdiff(xfun:::broken_packages(reinstall = FALSE), 'tcltk')) {
  remove.packages(i)
  install_extra(i)
}

# download source packages that have been updated on CRAN
if (file.exists(pkg_file <- file.path(dir, 'PACKAGES'))) {
  info = read.dcf(pkg_file, c('Package', 'Version'))
  info = info[info[, 1] %in% all_pkgs, , drop = FALSE]  # packages may be archived
  pkgs = setdiff(pkgs, info[as.numeric_version(db[info[, 1], 'Version']) <= info[, 2], 1])
}

# pkgs = intersect(pkgs, all_pkgs)

if (length(pkgs) == 0) q('no')

pkg_all = c(all_pkgs, rownames(installed.packages()))
for (pkg in pkgs) {
  if (pkg %in% all_pkgs) {
    # dependency not available on CRAN
    if (!all(xfun:::pkg_dep(pkg, db) %in% pkg_all)) next
    xfun:::download_tarball(pkg, db)
  } else {
    system2('git', c('clone', sprintf('https://github.com/cran/%s.git', pkg)))
    xfun::Rcmd(c('build', pkg))
    unlink(pkg, recursive = TRUE)
  }
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
  for (p in deps) {
    if (!xfun::loadable(p)) install_extra(p)
  }
  if (xfun::Rcmd(c('INSTALL', '--build', names(pkg))) != 0)
    failed <<- c(failed, pkg)
}
t0 = Sys.time()
install_deps(pkgs)  # install all brew dependencies for R packages
for (i in seq_along(pkgs)) {
  message('Building ', pkgs[i], ' (', i, '/', length(pkgs), ')')
  build_one(pkgs[i])
  # give up the current job to avoid timeout on Github Action this time; we can
  # continue the rest next time
  if (difftime(Sys.time(), t0, units = 'mins') > 300) break
}

if (length(failed)) warning('Failed to build packages: ', paste(failed, collapse = ' '))

file.copy(list.files('.', '.+[.]tgz$', full.names = TRUE), dir, overwrite = TRUE)
unlink(c('*.tar.gz', '*.tgz', '_AUTOBREW_BUILD', 'binaries'), recursive = TRUE)

# render the homepage index.html
local({
  x = home
  x[1] = paste0(x[1], '\n\n### Yihui Xie\n\n### ', Sys.Date(), '\n')
  # insert successfully built package names after a code block
  p = list.files(dir, r <- '_[-0-9.]+[.]tgz$')
  p = gsub(r, '', p)
  i = grep('rownames\\(available.packages', x)[1]
  x = append(x, c(
    '\n```', capture.output(print(p)), '```\n'
  ), which(x[i:length(x)] == '```')[1] + 1 + i)
  xfun::write_utf8(x, 'index.Rmd')
  xfun::pkg_load2('knitr')
  knitr::rocco('index.Rmd')
})
unlink(c('PACKAGES*', 'index.md', 'index.Rmd'))

tools::write_PACKAGES(dir, type = 'mac.binary')
saveRDS(sysreqsdb, sysdb)

system2('ls', c('-lh', dir))
system('du -sh .')
