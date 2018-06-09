# Binary R packages for the Homebrew R

[![Travis build status](https://travis-ci.com/yihui/homebrew-r-packages.svg?branch=master)](https://travis-ci.com/yihui/homebrew-r-packages)

Some binary R packages for the Homebrew version of base R on macOS. If you are using the Homebrew version of R (i.e., `brew install r`) on the latest version of macOS, you may set these options to install the binary packages:

```r
options(
  pkgType = 'mac.binary.el-capitan',
  repos = 'https://macos.rbind.org'
)
```

To see which packages are available:

```r
available.packages(repos = 'https://macos.rbind.org')
```

Currently this repo is mostly for myself (because there are several things I don't like about the base R installer on CRAN for macOS, and you have to install packages from source if you use the Homebrew version of R). Please consider it as highly experimental.
