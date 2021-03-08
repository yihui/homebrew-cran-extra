# Extra Binary R packages for the Homebrew R (Cask)

[![build-extra](https://github.com/yihui/crandalf/workflows/build-extra/badge.svg)](https://github.com/yihui/homebrew-cran-extra/actions)

The repository https://macos.rbind.io ([Github repo](https://github.com/yihui/homebrew-cran-extra)) provides some binary R packages for the Homebrew (cask) version of base R that are currently missing on CRAN, in a similar spirit as the "CRAN extras" repository for Windows: https://www.stats.ox.ac.uk/pub/RWin/. If you are using the Homebrew version of R on the latest version of macOS, you may set the `repos` option in R first:

```r
# you may do this in your ~/.Rprofile so you don't have to do it every time
options(repos = c(
  CRANextra = 'https://macos.rbind.io',
  CRAN = 'https://cran.rstudio.com'
))
```

Note that the `CRAN` repository does not have to be `https://cran.rstudio.com`. It can be any other CRAN mirror.

Then you will be able to install some binary packages with `install.packages()`, e.g.,

```r
install.packages(c('cairoDevice', 'RGtk2'))
```

To see which packages are available, use the function `available.packages()` in R:

```r
rownames(available.packages(
  repos = 'https://macos.rbind.io', type = 'binary'
))
```

## Why creating this repository?

CRAN maintainers have provided binaries for most R packages (big thanks!), but a few have still been missing so far. This repository serves as a complement to the official CRAN respository, and provides a subset of the binary R packages that are unavailable on CRAN.

To use this repository, you are expected to install the cask `r` from Homebrew (instead of the formula `brew install r`):

```sh
brew install --cask r
```

The R installer you manually downloaded and installed from CRAN should also work, but it is not tested here.

## Scope of the repository

The repository https://macos.rbind.io does not provide binary packages of these packages:

1. Packages of which the binaries already exist on CRAN (the package names are obtained as the differences between `available.packages(type = 'source')` and `available.packages(type = 'binary')`).

1. Packages that depend on BioConductor packages.

1. Packages of which the system dependencies are not available in Homebrew (e.g., `rggobi`) or too difficult to install (e.g., `kmcudaR`).

The repository is automatically updated daily from [Github Action](https://github.com/yihui/homebrew-cran-extra/actions), which means if a new version of a source R package appears on CRAN, its binary package should be available in this repository in less than 24 hours (if it satisfies the above conditions).

## Instructions on system dependencies

Some packages only require system dependencies at the build time, e.g., the R package **xml2** requires the brew package `libxml2` when building it from source, but `libxml2` is no longer needed once the binary package is built (after `install.packages('xml2')`, you can remove `libxml2`). However, some packages still need the system dependencies at the run time, such as **RGtk2** (you cannot `brew uninstall gtk+`). To install the system dependencies after installing a binary R package from `macos.rbind.io`, you may try:

```r
install.packages('xfun')
xfun:::install_brew_deps()
```

## Disclaimer

My knowledge of building binary R packages is fairly limited, so please consider this repository as experimental before real experts join me. I'd welcome anyone to help with this project. In the same spirit of Homebrew, I really wish this will become a project maintained by the community instead of me alone.

## Related work

This repository is based on Jeroen Ooms's work <https://github.com/r-hub/homebrew-cran>. My major work was to create an actual CRAN-like repository to host the binary packages, and figure out the brew package dependencies for a few R packages that are not (yet) covered by the `r-hub/homebrew-cran` project. Please note that `r-hub/homebrew-cran` aims at _static linking_, so that you can get rid of the brew packages once the binary R packages are built, but some binary packages in this repo `macos.rbind.io` still require the brew packages to remain installed in your system (such as **RGtk2**, which requires `brew install gtk+`).

## License

The source code in the [Github repo](https://github.com/yihui/homebrew-cran-extra) is licensed under MIT. For the R packages, please consult their DESCRIPTION files for their specific licenses. The copyright of these packages belongs to their original authors. You may obtain the source code of these R packages from CRAN if you wish to.
