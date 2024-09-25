# tullaRange release notes

## 11.0.6

* Update TOCs for 4.4.1 and 1.15.3

## 11.0.5

* Fix an error caused by the retrieval of a nil value when checking the spell costs of a macro.

## 11.0.4

* Fixed an issue causing range checking to incorrectly revert actions to displaying as usable, 
  even if they are not

## 11.0.3

* Drop visibility chek from UpdateUsable calls in Retail

## 11.0.2

* Fix IsUsableSpell typo

## 11.0.1

* Fixed errors when summoning a pet in WoW 11.0.2

## 11.0.0

* Fix an options menu error in WoW 11.0.0
* Update TOCs for 11.0.2 and 1.15.3

## 10.2.6

* Update TOCs

## 10.2.5

* Added initial War Within support
* Update TOCs for 11.0.0 and 10.2.7

## 10.2.4

* Update TOCs

## 10.2.3

* Update TOCs for 1.15.1
* Fixed an issue causing the options menu sliders to not render properly in Classic

## 10.2.2

* Update TOCs for 10.2.5

## 10.2.1

* Update TOCs for 3.4.3 and 1.15.0

## 10.2.0

* Update TOCs for 10.2.0

## 10.1.8

* Revert TOC back to 3.4.2

## 10.1.7

* Update TOCs for 10.1.7, 3.4.3, and 1.14.4

## 10.1.6

* Fix an issue causing acton buttons to be registered multiple times

## 10.1.5

* Note: This version does not work on 10.1.0 realms (aka Retail)
* (WoW 10.1.5) Rebuilt using the new ACTION_RANGE_CHECK_UPDATE event
* (WoW 3.4.2) Fixed an error when loading the settings UI
* Hotkeys are now colored red when an action is out of range, and white otherwise.
* Pet actions now implement out of mana coloring

## 10.1.0

* Update TOCs for World of Warcraft 10.1.0
* Hook ActionBarActionButtonDerivedMixin, if it exists

## 10.0.11

* Update TOCs for World of Warcraft 10.0.5

## 10.0.10

* Update TOCs for World of Warcraft 3.4.1

## 10.0.9

* Fix macro checks

## 10.0.8

* Added [Hollicsh](https://github.com/Hollicsh)'s Russian localization

## 10.0.7

* Removed a leftover debug green background from the options menu

## 10.0.6

* Apply [Odjur](https://github.com/Odjur)'s optimizations
* Add desaturate to configuration settings
* Add update frequency to internal configuration settings
* Readjust UI to implement desaturate and opacity settings

## 10.0.5

* No longer desaturating when unusable, just out of range or out of mana

## 10.0.4

* Desaturate when recoloring abilities (thanks to Guema)

## 10.0.3

* Updated TOC files for 10.0.2

## 10.0.2

* Improve check for new Settings UI

## 10.0.1

* Add support for 10.0.0

## 9.2.1

* Updated TOC files for 9.2.5, 3.4.0, 2.5.4, and 1.14.3.

## 9.2.0

* Updated TOC files for 9.2.0, 2.5.3, and 1.14.2.
* Packaged the addon using multiple TOC files

## 9.1.1

* Updated TOC files

## 9.1.0

* Updated TOC files for 9.1.0

## 9.0.4

* Add Burning Crusade Classic support

## 9.0.3

* If you create a macro with a name that starts with #, tullaRange will now use spell cost checks to determine if the ability is usable (thanks merijn)
* Updated TOCs for various wow versions

## 9.0.2

* Updated TOC for 9.0.2

## 9.0.1

* Fix a nil value exception when moving pet actions

## 9.0.0

* Updated for World of Warcraft 9.0.1 - Shadowlands

## 8.3.2

* Added support for pet action buttons. You can disable this via `/run tullaRange:SetEnablePetActions(false)`
* Replaced the attack flash animation with a smoother one. You can disable this via `/run tullaRange:SetEnableFlashAnimations(false)`

## 8.3.1

* Increase performance a bit by only updating attack actions and actions with a range

## 8.3.0

* Update for WoW 8.3.0

## 8.2.7

* Use a C_Timer.After handler for updates

## 8.2.6

* Update classic TOC for 1.13.2
* Update packager to use github actions

## 8.2.5

* Updated TOC for 8.2.5

## 8.2.2

* Added classic build

## 8.2.1

* Automated releases

## 8.2.0

* Updated TOC for 8.2.0
* Verified the addon works with classic
* Cleaned up code a tiny bit
