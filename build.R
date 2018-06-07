ver = unlist(getRversion())[1:2]  # version x.y
dir = file.path('bin/macosx/el-capitan/contrib', paste(ver, collapse = '.'))
dir.create(dir, recursive = TRUE, showWarnings = FALSE)

# install xfun (from Github)
if (!requireNamespace('xfun') || packageVersion('xfun') <= '0.1') {
  source('https://install-github.me/yihui/xfun')
}

for (pkg in readLines('packages')) {
  if (!xfun::loadable(pkg, new_session = TRUE)) install.packages(pkg)
}

tools::write_PACKAGES(dir, type = 'mac.binary')
