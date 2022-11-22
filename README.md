# Dynamic Playlist Creator - BETA

**Dynamic Playlist Creator** [^1] is a companion plugin for the *Dynamic Playlists 3* plugin. It helps you create dynamic playlists using templates.<br><br>
It is a **BETA** version because I expect bugs in the templates and I won't release an untested plugin. **I don't use this plugin myself and don't have the time to test the templates against all possible parameter combinations**.<br><br>
If *enough* beta testers come forward to test the templates **extensively** (thank you!), perhaps one day this plugin can be part of the LMS plugin repository.<br>
Until then, it will continue to be a beta version with updates as bug reports come in.
<br><br><br>


## Requirements
- latest Dynamic Playlists version 3 or 4

- LMS version ≥ 7.9

- LMS  database = SQLite. Preferably without major problems to avoid false positives.

- **GitHub account** to post bug reports. **Everything** should be handled **on GitHub**, **not** the LMS forum. I'm just not there that much anymore.

- You understand that this is a **beta** version. It's believed to contain bugs and is provided on an “as is” and “as available” basis without any warranty. You should not rely in any way on the correct functioning or performance of a beta version. In no case am I responsible/liable for any damages whatsoever arising out of the use of this plugin.

- Patience
<br><br><br>


## What to test for
Look for **template** bugs in particular.<br>
Just **create dynamic playlists from each template**. Try *different* (combinations of) *parameters* for each dynamic playlist you create. Then play them with *Dynamic Playlists 3*. This beta is mainly about finding bugs, not about making feature requests.
<br><br><br>


## Report a bug
Template bugs will usually give you sql errors (see server log) or result in tracks that do not match your parameter selection at all. When in doubt, try to find/play a similar *built-in* dynamic playlist to make sure it's a template bug and not problems in your database.<br><br>
If you think that you've found a bug, open an [**issue here on GitHub**](https://github.com/AF-1/lms-dynamicplaylistcreator/issues) and fill out the ***Bug report* issue template**. Please post bug reports on **GitHub only**.<br>
<br><br><br>


## Installation

Add the repository URL below at the bottom of *LMS* > *Settings* > *Plugins* and click *Apply*:<br><br>
[**https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml**](https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml)
<br><br><br>


## Notes

- DPLC will *always* save a fully “fleshed out” SQLite playlist, even if you use the recommended *Default format* (xml), because *Dynamic Playlists 3* scans the DPLC custom folder for **sql** files. That's how the dynamic playlists you create with DPLC get listed in *Dynamic Playlists 3*.
- I have combined some templates. Example: *Least/most played* is now an option in other templates.
- Compatible with *Dynamic Playlists 3*, *Custom Skip 3* and *Alternative Play Count*. CustomScan: untested.
- You can't import or migrate dynamic playlist definitions from the SQLPlayList plugin. The templates are different.
- This plugin will not be localized because parameter names and value names are baked into the templates. And a halfway localized version is worse than a non-localized one.
<br>

[^1]:inspired by and based on Erland's SQLPlayList