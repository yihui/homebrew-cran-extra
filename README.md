# Extra Binary R packages for the Homebrew R (Cask)

[![Travis build status](https://travis-ci.com/yihui/homebrew-cran-extra.svg?branch=master)](https://travis-ci.com/yihui/homebrew-cran-extra)

The repository https://macos.rbind.org ([Github repo](https://github.com/yihui/homebrew-cran-extra)) provides some binary R packages for the Homebrew (cask) version of base R that are currently missing on CRAN, in a similar spirit as the "CRAN extras" repository for Windows: https://www.stats.ox.ac.uk/pub/RWin/. If you are using the Homebrew version of R on the latest version of macOS, you may set the `repos` option in R first:

```r
# you may do this in your ~/.Rprofile so you don't have to do it every time
options(repos = c(
  CRAN = 'https://cran.rstudio.com', CRANextra = 'https://macos.rbind.org'
))
```

Note that the `CRAN` repository does not have to be `https://cran.rstudio.com`. It can be any other CRAN mirror.

Then you will be able to install some binary packages with `install.packages()`, e.g.,

```r
install.packages(c('cairoDevice', 'RGtk2'))
```

To see which packages are available, use the function `available.packages()` in R:

```r
available.packages(repos = 'https://macos.rbind.org', type = 'binary')
```

## Why creating this repository?

I believe in [Homebrew](https://brew.sh), the "missing package manager for macOS". The one thing I love it most is, _automation_, and no `sudo` required (there are a few exceptions in brew casks, but in general, you won't need `sudo`). Anything (in software) that cannot be easily automated concerns me. I'm tired of the process "Google, open the download page, download `*.pkg` or `*.dmg`, open it, drag the app or follow a wizard and input password". I'm even more tired of `./configure && make && make install` and searching for all kinds of missing C headers. The other thing I love about Homebrew is that it is maintained by a large community instead of any single person. My third favorite feature of Homebrew is that you can _cleanly_ install and remove software packages with simple commands. If you have ever tried to to uninstall the CRAN version of base R, I believe you should understand what it means (more on this later).

For base R, you can easily install it in Homebrew:

```sh
brew install r  # to remove it: brew uninstall r
```

But when it comes to installing add-on R packages on CRAN that require compilation (i.e., containing C/C++/Fortran code), you may be in pain because some packages take long time to compile. Besides, when R packages have external system dependencies, things can be more complicated. My hair had turned gray several times when I tried to [install **RGtk2** on macOS](https://yihui.name/en/2018/01/install-rgtk2-macos/).

Basically, if you choose to use the Homebrew version of R, you have to install R packages from source. You can verify it with `getOption('pkgType')`, which should return `"source"` unless you have changed the default options like above. You _might_ be able to install some binary packages from CRAN, but there is no guarantee that they will actually work.

## Scope of the repository

First of all, the repository https://macos.rbind.org does not intend to provide binaries of _all_ packages on CRAN. Its spirit is more like the repository https://www.stats.ox.ac.uk/pub/RWin/ for R on Windows. It is targeted at two types of R packages: those that take long time to compile (such as **stringi**, which can take several minutes), and those with relatively heavy system dependencies (such as **RGtk2**, which requires `gtk+`). Among these packages, currently I manually selected a few that I need to install in my system. To see how I looked for packages that take long time to compile, see the script [packages.R](https://github.com/yihui/homebrew-cran-extra/blob/master/packages.R):

```r
`r xfun::file_string('packages.R')`
```

If there are any other packages that you frequently use and satisfy the above criteria, please free free to [edit the `packages` file](https://github.com/yihui/homebrew-cran-extra/edit/master/packages) and submit a pull request.

The repository is automatically updated daily (from Travis CI), which means if a new version of a source R package appears on CRAN, and the package is included in this repository, the binary package should be available in less than 24 hours.

If you try to install a package from https://macos.rbind.org but its binary package is not available, it will automatically redirect you to the RStudio CRAN mirror https://cran.rstudio.com and let you install the source package instead.

## Instructions on system dependencies

Some packages only require system dependencies at the build time, e.g., the R package **xml2** requires the brew package `libxml2` when building it from source, but `libxml2` is no longer needed once the binary package is built (after `install.packages('xml2')`, you can remove `libxml2`). However, some packages still need the system dependencies at the run time, such as **RGtk2** (you cannot `brew uninstall gtk+`). It is possible to automate the installation of system dependencies when installing a binary R package from `macos.rbind.org`, but for now, I'll just list a few known cases below:

- **RGtk2** and **cairoDevice** require `gtk+`.

- **RProtoBuf** requires `protobuf`.

- For **rJava**, if you didn't install JDK from Homebrew, you can [uninstall Java](https://www.java.com/en/download/help/mac_uninstall_java.xml), and then `brew cask install java; R CMD javareconf`. Then `install.packages('rJava')` should be okay.

- The **tcltk** package is not supported.

## Why modify `base::.Platform$pkgType`?

For those who are curious about the reason for the dirty hack on modifying `.Platform$pkgType`, see [`src/main/platform.c`](https://github.com/wch/r-source/blob/e4e1efe/src/main/platform.c#L176-L180) in the source of base R, and search for `#define PLATFORM_PKGTYPE` in [Simon's script `buildR`](https://svn.r-project.org/R-dev-web/trunk/QA/Simon/R-build/buildR). Only Simon's build (i.e., CRAN's build) of base R has defined the macro `PLATFORM_PKGTYPE`, which makes `.Platform$pkgType` return something like `mac.binary.el-capitan`. This is crucial for `install.packages(..., type = 'both')`, because otherwise it will fail with the error "[type 'binary' is not supported on this platform](https://github.com/wch/r-source/blob/a44aa4737/src/library/utils/R/packages2.R#L142-L145)".

Here is my challenge: Is it possible to define the macro `PLATFORM_PKGTYPE` in the [Homebrew formula of R](https://github.com/Homebrew/homebrew-core/blob/master/Formula/r.rb) like what CRAN does, so that we don't need to hack at `.Platform`?

## How to uninstall the CRAN version of R?

It is certainly not as simple as `brew uninstall r` if you installed `R-x.x.x.pkg` [from CRAN](https://cran.rstudio.com/bin/macosx/). You may also have installed customized versions of Clang and GNU Fortran from there. And have you downloaded and installed XQuartz manually, too? To get rid of these packages, you need to carefully read the R manual "[R Installation and Administration](https://cran.rstudio.com/doc/manuals/r-release/R-admin.html)" the Stack Overflow post "[Uninstall packages in Mac OS X](https://stackoverflow.com/q/25925752/559676)" (use `pkgutil --pkgs | grep r-project` to get a possible list of packages, and note that you may have installed multiple versions of R without realizing it). Please be really cautious. I once deleted my whole `/usr` directory by accident because I forgot the `--only-files` flag when calling `pkgutil`.

Given the complexity, I believe you don't want to do this twice in your life. Of course, this is not a problem of R _per se_, but a general problem of macOS. I think even Windows is better in terms of uninstalling software.

## Disclaimer

This was pretty much a two-day side-project on which I worked when I was trying to install thousands of R packages to check the reverse dependencies of **knitr** and **rmarkdown**. I had been frustrated enough by certain problems such as the missing **RGtk2** binary on CRAN, and finally decided to take a stab at building binary R packages for the Homebrew version of R. However, my knowledge in this area is fairly limited, so please consider this repository as experimental before real experts join me. I'd welcome anyone to help with this project. In the same spirit of Homebrew, I really wish this will become a project maintained by the community instead of me alone. 

## Related work

Jeroen Ooms has worked on building binary R packages with the CRAN version of R. You can find more information in the Github repo <https://github.com/r-hub/homebrew-cran>. As I have indicated, I'm not interested in the CRAN version of R, and I prefer everything being in the Homebrew world if possible.

## License

The source code in the [Github repo](https://github.com/yihui/homebrew-cran-extra) is licensed under MIT. For the R packages, please consult their DESCRIPTION files for their specific licenses. The copyright of these packages belongs to their original authors. You may obtain the source code of these R packages from CRAN if you wish to.
