# Dynamic Playlist Creator

**Dynamic Playlist Creator** [^1] allows you to create *custom* dynamic playlists for the *Dynamic Playlists* plugin using templates.<br><br>
It's a **BETA** version. It probably still contains some (template) bugs and is provided on an “as is” and “as available” basis without any warranty or liability on my part. **I simply don't have the time to test the templates against all possible parameter combinations**. But if *enough* beta testers come forward to test the templates **extensively** (thank you!), perhaps one day this plugin can be part of the LMS plugin repository.<br>
Until then, this plugin will continue to be officially a beta version with updates as bug reports come in, even if it's already working.
<br><br><br>


## Requirements
- Dynamic Playlists version **3**.7.7 or **4**.x

- LMS version ≥ 7.9

- LMS  database = SQLite. Preferably without major problems to avoid false positives.
<br><br><br>


## How to contribute as a beta user
Use the plugin to **create custom dynamic playlists**. Try different *templates* and *different* (combinations of) *parameters* for each dynamic playlist you create. Then play them with *Dynamic Playlists* to see if they work.
<br><br><br>


## Report a bug
If you think that you've found a bug, open an [**issue here on GitHub**](https://github.com/AF-1/lms-dynamicplaylistcreator/issues) and fill out the ***Bug report* issue template** including as much information as possible.<br>
Please post bug reports on **GitHub only**, **not** the LMS forum.
<br>
<br><br><br>


## Installation

Add the repository URL below at the bottom of *LMS* > *Settings* > *Plugins* and click *Apply*:<br><br>
[**https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml**](https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml)
<br><br><br>


## Notes

- DPLC will *always* save a fully “fleshed out” SQLite playlist, even if you use the recommended *Default format* (xml), because *Dynamic Playlists* scans the DPLC custom folder for **sql** files. That's how the dynamic playlists you create with DPLC get listed in *Dynamic Playlists*.
- I have combined some templates. Example: *Least/most played* is now an option in other templates.
- Compatible with *Dynamic Playlists* (version 3 or higher), *Custom Skip* 3 and *Alternative Play Count*. CustomScan: untested.
- You **can't** import or migrate dynamic playlist definitions from the *SQLPlayList* plugin. The templates are different.
- This plugin will not be localized because parameter names and value names are baked into the templates. And a halfway localized version is worse than a non-localized one.
<br>

[^1]:inspired by and based on Erland's SQLPlayList