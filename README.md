# Binary R packages for the Homebrew R

[![Travis build status](https://travis-ci.com/yihui/homebrew-r-packages.svg?branch=master)](https://travis-ci.com/yihui/homebrew-r-packages)

This repository provides some binary R packages for the Homebrew version of base R on macOS. If you are using the Homebrew version of R on the latest version of macOS, you may set these options, and install the binary packages with `install.packages()`:

```r
# you may want to do this in your ~/.Rprofile
local({
  if (Sys.info()[['sysname']] != 'Darwin) return()

  # a very dirty hack to be explained later
  .Platform$pkgType = 'mac.binary.el-capitan'
  unlockBinding('.Platform', baseenv())
  assign('.Platform', .Platform, 'package:base')
  lockBinding('.Platform', baseenv())

  options(
    pkgType = 'both', install.packages.compile.from.source = 'always',
    repos = 'https://macos.rbind.org'
  )
})
```

To see which packages are available, open the [packages](https://github.com/yihui/homebrew-r-packages/blob/master/packages) file in this repo, or use the function `available.packages()` in R:

```r
available.packages(repos = 'https://macos.rbind.org', type = 'binary')
```

## Why?

I believe in [Homebrew](https://brew.sh), the "missing package manager for macOS". The one thing I love it most is, _automation_, and no `sudo` required^[There are a few exceptions in brew casks, but in general, you won't need `sudo`.]. Anything (in software) that cannot be easily automated concerns me. I'm tired of the process "Google, open the download page, download `*.pkg` or `*.dmg`, open it, drag the app or follow a wizard and input password". I'm even more tired of `./configure && make && make install` and searching for all kinds of missing C headers. The other thing I love about Homebrew is that it is maintained by a large community instead of any single person. My third favorite feature of Homebrew is that you can _cleanly_ install and remove software packages with simple commands. If you have ever tried to to uninstall the CRAN version of base R, I believe you should understand what it means (more on this later).

For base R, you can easily install it in Homebrew:

```sh
brew install r  # to remove it: brew uninstall r
```

But when it comes to installing add-on R packages on CRAN that require compilation (i.e., containing C/C++/Fortran code), you may be in pain because some packages take long time to compile. Besides, when R packages have external system dependencies, things can be more complicated. My hair had turned gray several times when I tried to [install **RGtk2** on macOS](https://yihui.name/en/2018/01/install-rgtk2-macos/).

Basically, if you choose to use the Homebrew version of R, you have to install R packages from source. You can verify it with `getOption('pkgType')`, which should return `"source"` unless you have changed the default options like above. You _might_ be able to install some binary packages from CRAN, but there is no guarantee that they will actually work.

## Scope

First of all, the repository https://macos.rbind.org does not intend to provide binaries of _all_ packages on CRAN. It is targeted at at two types of R packages: those that take long time to compile (such as **stringi**, which can take several minutes), and those with relatively heavy system dependencies (such as **RGtk2**, which requires `gtk+`). Among these packages, currently I manually selected a few that I need to install in my system. To see how I looked for packages that take long time to compile, see the script [packages.R](https://github.com/yihui/homebrew-r-packages/blob/master/packages.R):

```r
`r xfun::file_string('packages.R')`
```

If there are any other packages that you frequently use and satisfy the above conditions, please free free to [edit the `packages` file](https://github.com/yihui/homebrew-r-packages/edit/master/packages) and submit a pull request.

If you try to install a package from https://macos.rbind.org but its binary package is not available, it will automatically redirect you to the RStudio CRAN mirror https://cran.rstudio.com and let you install the source package instead.

## Why modify `base::.Platform$pkgType`?

For those who are curious about the reason for the dirty hack on modifying `.Platform$pkgType`, see [`src/main/platform.c`](https://github.com/wch/r-source/blob/e4e1efe/src/main/platform.c#L176-L180) in the source of base R, and search for `#define PLATFORM_PKGTYPE` in [Simon's script `buildR`](https://svn.r-project.org/R-dev-web/trunk/QA/Simon/R-build/buildR). Only Simon's build (i.e., CRAN's build) of base R has defined the macro `PLATFORM_PKGTYPE`, which makes `.Platform$pkgType` return something like `mac.binary.el-capitan`. This is crucial for `install.packages(..., type = 'both')`, because otherwise it will fail with the error "[type 'binary' is not supported on this platform](https://github.com/wch/r-source/blob/a44aa4737/src/library/utils/R/packages2.R#L142-L145)".

Here is my challenge: Is it possible to define the macro `PLATFORM_PKGTYPE` in the Homebrew version of R like what CRAN does, so that we don't need to hack at `.Platform`?

## Home to uninstall the CRAN version of R?

