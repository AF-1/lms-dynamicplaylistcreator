# Dynamic Playlist Creator

**Dynamic Playlist Creator**[^1] (DPLC) allows you to create *custom* dynamic playlists for the *Dynamic Playlists* plugin using templates.<br>
The target group for this plugin are users who want to create customized dynamic playlists quickly and easily using **only** the templates and **not** working directly with SQLite statements. Accordingly, DPLC does **not include the option to manually edit SQLite statements** (see FAQ).<br><br>
Please note that this is and will remain a [**release candidate**](https://en.wiktionary.org/wiki/release_candidate) version for the foreseeable future until *enough* users have tested the templates **extensively** (thank you!). I simply don't have the time to test the templates against all possible parameter combinations. It's provided on an “as is” and “as available” basis without any warranty/liability on my part.
<br><br>
[⬅️ **Back to the list of all plugins**](https://github.com/AF-1/)
<br><br><br>


## Requirements
- Dynamic Playlists version **4**

- LMS version ≥ 7.9

- LMS  database = SQLite. Preferably without major problems to avoid false positives.

- A GitHub account if you want to report a bug.
<br><br><br>


## How to contribute as a user
Use the plugin to **create custom dynamic playlists**. Try different *templates* and *different* (combinations of) *parameters* for each dynamic playlist you create. Then play them with *Dynamic Playlists* to see if they work.
<br><br><br>


## Report a bug
If you think that you've found a bug, open an [**issue here on GitHub**](https://github.com/AF-1/lms-dynamicplaylistcreator/issues) and fill out the ***Bug report* issue template** including as much information as possible.<br>
Please post bug reports on **GitHub only**, **not** the LMS forum.
<br><br><br><br>


## Installation
⚠️ **Please read the [FAQ](https://github.com/AF-1/lms-dynamicplaylistcreator#faq) *before* installing this plugin.**<br>

Add the repository URL below at the bottom of *LMS* > *Settings* > *Plugins* and click *Apply*:<br><br>
[**https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml**](https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml)
<br><br><br><br>


## FAQ

<details><summary>»<b>Can I import my custom dynamic playlists from the <i>SQLPlayList</i> plugin?</b>«</summary><br><p>
No, you <b>can't</b> import or migrate dynamic playlist definitions from the <i>SQLPlayList</i> plugin to <i>Dynamic Playlist <b>Creator</b></i>. They are based on templates which are different from the ones that DPLC uses.
</p></details><br>

<details><summary>»<b>I cannot manually edit the SQLite statement of my dynamic playlists in DPLC.</b>«<br>&nbsp;&nbsp;&nbsp;&nbsp;»<b>What does the <i>export</i> button do?</b>«</summary><br><p>
The target group for this plugin are users who want to create customized dynamic playlists quickly and easily using <b>only the templates</b> and <b>not</b> working directly with SQLite statements. Accordingly, DPLC does <b>not include the option to manually edit SQLite statements</b> in a tiny text area. Users familiar with SQLite (who are not the target group for this plugin) can manually edit their SQLite statements outside of DPLC using a plain text editor of their choice.<br><br>
If you have to <b>manually edit the SQLite statement of a dynamic playlist <i>currently managed by DPLC</i></b>, you can <b>use the <i>export</i> button</b> to move the dynamic playlist to the <i>Dynamic Playlists</i> plugin, i.e. its folder for custom dynamic playlists called <b>DPL-custom-lists</b>. There you can edit it like any other custom dynamic playlist using your favorite plain text editor.<br>
The moved dynamic playlist is deleted from DPLC and now managed directly by the <i>Dynamic Playlists</i> plugin.
</p></details><br>

<details><summary>»<b>What are the files in the <i>DynamicPlaylistCreator</i> folder for? Can I edit them?</b>«</summary><br><p>
When you create/edit and then <i>save</i> a custom dynamic playlist, DPLC will create 2 files in the <i>DynamicPlaylistCreator</i> folder (default location in the LMS playlists folder, can be changed in the plugin settings):<br>
the file with the <b>customvalues.xml</b> extension contains the (template) values you selected for this dynamic playlist. It allows you to edit or update your custom dynamic playlist at a later time.<br>
In addition, DPLC will <b>always</b> save your custom dynamic playlist as an SQLite statement (file extension: <b>sql</b>) because <i>Dynamic Playlists</i> searches the DPLC custom folder for them.<br><br>
<b>Do <i>not</i> manually move or edit any of these files!</b> DPLC will overwrite the changes. Or worse, your custom dynamic playlist will no longer work.
</p></details><br>

<details><summary>»<b>Why is the <i>Play button</i> to <i>start</i> dynamic playlists directly from the list of created dynamic playlists in DPLC not displayed for <i>all</i> dynamic playlists?</b>«</summary><br><p>
You can <b>only</b> start dynamic playlist directly in DPLC that do <b>not ask for user input when started</b>. DPLC does not contain code to handle user-input parameters. To make it easier to maintain and update the plugin, I decided to create DPLC as a sort of dynamic playlist construction kit without duplicating any code from the <i>Dynamic Playlists</i> plugin.
</p></details><br>

<details><summary>»<b>Which plugins does DPLC work with?</b>«</summary><br><p>
It works with <a href="https://github.com/AF-1/lms-dynamicplaylists#faq"><b>Dynamic Playlists 4</b></a>, <a href="https://github.com/AF-1/lms-alternativeplaycount"><b>Alternative Play Count</b></a> and <a href="https://github.com/AF-1/lms-customskip#custom-skip"><b>Custom Skip 3</b></a>.<br><b>CustomScan</b>: could work, not tested. Compatibility not guaranteed, not supported by me.
</p></details><br>

<details><summary>»<b>In some DPLC templates there's no option to set a <i>track limit</i> and no “do not repeat” setting.</b>«</summary><br><p>
Dynamic playlists that use DPL <b>4</b>'s <b>cache option</b> cannot have a track limit because DPL 4 will load <b>all</b> track IDs matching the dynamic playlist's search parameter into the cache. The cached track ID list should not have duplicates, hence no “do not repeat” option. DPL 4 will add small batches of tracks from this list to the players's current playlist. The number of new unplayed tracks to be added per batch can be set in the DPL settings. It's a global setting for all dynamic playlists (except album dynamic playlists which should add complete albums).
</p></details><br>

<details><summary>»<b>Can I use <i>Dynamic Playlist Creator</i> and <i>SQLPlayList</i> at the same time?</b>«</summary><br><p>
Yes. <i>Dynamic Playlists</i> version <b>4</b> will ignore SQLPlayList. There's no benefit but no harm either in keeping it installed.
</p></details><br>

<details><summary>»<b>Can you translate DPLC into my language?</b>«</summary><br><p>
This plugin will not be localized because parameter names and value names are baked into the templates. And a halfway localized version is worse than a non-localized one.
</p></details><br>
<br>

[^1]:inspired by and based on Erland's SQLPlayList