# Nyan Cat Progress Indicator

The Nyan Cat Progress Indicator replaces your Mac's progress bars with an animation of Nyan Cat, similar to the progress bar that briefly adorned the [Nyan Cat Youtube Video](http://www.youtube.com/watch?v=QH2-TGUlwu4) and the [Windows progress bar](http://www.instantelevatormusic.com/nyan-cat-progress-bar).

It features hand-redized graphics derived from the original Pop Tart Cat GIF.

![Software Update window](https://github.com/michaelbuckley/ncprogressindicator/raw/master/software-update.png)

Developers may also compile the code as a framework to include the Nyan Cat Progress Indicator in their own applications. See the licence details below.

## Requirements

This software requires an Intel Macintosh running Snow Leopard or later. It may be possible to compile the plugin to run on earlier versions of Mac OS X, or on Power PC, but I cannot guarantee that it will work, and as I was unable to test on these configurations, the compiled binary made availiable on GitHub does not support them.

## Limitations

As the Nyan Cat Progress Indicator is a SIMBL plugin, and so has the same limitations as all SIMBL plugins. It will not work in the folliwing applications.

    * Login Window
    * Finder (including file copy dialogs)
    * iTunes
    * DVD Player

Additionally, on Lion, any applications which are restored on restart will use not use the Nyan Cat Progress Indicator. Likewise, applications which use custom progress bars, such as Tramsission, will still use their custom progress bars.

Unfortunately, there are not many applications that use progress bars in Mac OS X. However, you can find them by choosing "Software Update…" from the Apple Menu or in Safari's downloads window.

## Installation

As with all SIMBL plugins, the Nyan Cat Progress Indicator modifies the code of the applications on your system, and it may cause instability on your Mac. It is important to know how to remove the plugin should it cause problems for you. Therefore, there is no installer provided. Luckily, installation is simple.

    1. Install [SIMBL](http://www.culater.net/software/SIMBL/SIMBL.php)
    2. Place `NCProgressIndicator-SIMBL.bundle` into `~/Library/Application Support/SIMBL/Plugins`

You must create the `SIMBL/Plugins` folder if it does not already exist. On Lion, you can follow [these instructions](http://osxdaily.com/2011/07/22/access-user-library-folder-in-os-x-lion/) to open the `~/Library` folder.

## License

The graphics included are licensed under a [Creative Commons Attribution-NonCommercial 3.0 Unported License](http://creativecommons.org/licenses/by-nc/3.0/) with the attribution license listed below. The code is licensed under an MIT license.

Attribution Notice:
The graphics distributed with this code are derived from the original Pop Tart Cat gif created by Chris Torres, located at [http://www.prguitarman.com/index.php?id=348](http://www.prguitarman.com/index.php?id=348)
