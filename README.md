# Dynamic Playlist Creator

**Dynamic Playlist Creator**[^1] allows you to create *custom* dynamic playlists for the *Dynamic Playlists* plugin using templates.<br><br>
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
No, you <b>can't</b> import or migrate dynamic playlist definitions from the <i>SQLPlayList</i> plugin to <i>Dynamic Playlist <b>Creator</b></i>. They are based on templates which are different from the ones that DPLC uses.<br><br>
However, if you've saved your dynamic playlist in SQLPlayList as <b>customized SQL</b>, you could try to <b>use it directly in Dynamic Playlists</b>:<br>

- locate your dynamic playlist definition file <i>filename<b>.sql.xml</b></i><br>

- change the file extension to <b>sql</b>, i.e. lose the <i>xml</i><br>

- move the file to Dynamic Playlist's folder for custom dynamic playlists called <b>DPL-custom-lists</b>.<br><br>

If you want to use a custom dynamic playlist with DPL version <b>4</b>, you'll have to make sure that it returns track <b>ids</b>, not track <b>urls</b>.<br>See <a href="https://github.com/AF-1/lms-dynamicplaylists#faq"><b>DPL upgrade FAQ</b></a>.
</p></details><br>

<details><summary>»<b>What are the files in the <i>DynamicPlaylistCreator</i> folder for? Can I edit them?</b>«</summary><br><p>
When you create/edit and then <i>save</i> a custom dynamic playlist, DPLC will create 2 files in the <i>DynamicPlaylistCreator</i> folder (default location in the LMS playlists folder, can be changed in the plugin settings):<br>
the file with the <b>customvalues.xml</b> extension contains the (template) values you selected for this dynamic playlist. It allows you to edit or update your custom dynamic playlist at a later time.<br>
In addition, DPLC will <b>always</b> save your custom dynamic playlist as an SQLite statement (file extension: <b>sql</b>) because <i>Dynamic Playlists</i> searches the DPLC custom folder for them.<br><br>
<b>Do <i>not</i> manually move or edit any of these files!</b> DPLC will overwrite the changes. Or worse, your custom dynamic playlist will no longer work.
</p></details><br>

<details><summary>»<b>Why can't I <i>start</i> dynamic playlists from the list of created dynamic playlists in DPLC?</b>«</summary><br><p>
DPLC does not contain any code to play songs or handle parameters - which it would need to start dynamic playlists with <i>user-input parameters</i>. SQLPlayList contained a lot of duplicate code from DPL <b>2</b> especially for this purpose. I guess, this was rather unproblematic and manageable at the time, because the number of user-input parameters in DPL <b>2</b> was more limited and less complex (no multiple selections, no preselection etc.).<br>
I decided to create DPLC more as a kind of dynamic playlist construction kit without duplicate code, which should make the plugin easier to maintain and update. That's why there's no play button in DPLC.
</p></details><br>

<details><summary>»<b>Which plugins does DPLC work with?</b>«</summary><br><p>
It's compatible with <a href="https://github.com/AF-1/lms-dynamicplaylists#faq"><b>Dynamic Playlists 4</b></a>, <a href="https://github.com/AF-1/lms-alternativeplaycount"><b>Alternative Play Count</b></a> and <a href="https://github.com/AF-1/lms-customskip#custom-skip"><b>Custom Skip 3</b></a>.<br><b>CustomScan</b>: could work, not tested. Compatibility not guaranteed, not supported by me.
</p></details><br>

<details><summary>»<b>In some DPLC templates there's no option to set a <i>track limit</i>.</b>«</summary><br><p>
Dynamic playlists that use DPL <b>4</b>'s <b>cache option</b> cannot have a track limit because DPL 4 will load <b>all</b> tracks matching the dynamic playlist's search parameter into the cache. DPL 4 will then add small batches of tracks to the players's current playlist. The number of new unplayed tracks to be added per batch can be set in the DPL settings. It's a global setting for all dynamic playlists (except album dynamic playlists which should add complete albums).
</p></details><br>

<details><summary>»<b>Can I use <i>Dynamic Playlist Creator</i> and <i>SQLPlayList</i> at the same time?</b>«</summary><br><p>
Yes. <i>Dynamic Playlists</i> version <b>4</b> will ignore SQLPlayList but there's no harm in keeping it installed.
</p></details><br>

<details><summary>»<b>Can you translate DPLC into my language?</b>«</summary><br><p>
This plugin will not be localized because parameter names and value names are baked into the templates. And a halfway localized version is worse than a non-localized one.
</p></details><br>
<br>

[^1]:inspired by and based on Erland's SQLPlayList