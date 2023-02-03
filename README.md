# Dynamic Playlist Creator

**Dynamic Playlist Creator**[^1] (DPLC) allows you to create *custom* dynamic playlists for the *Dynamic Playlists* plugin using templates.<br>
The target group for this plugin is users who want to quickly and easily create custom dynamic playlists using **only** templates and **not** working directly with SQLite statements. Accordingly, DPLC does not include the option to manually edit SQLite statements (see FAQ).
<br><br>
[⬅️ **Back to the list of all plugins**](https://github.com/AF-1/)
<br><br><br>


## Requirements
- Dynamic Playlists version **4**

- LMS version ≥ 7.9

- LMS database = SQLite
<br><br><br>


## Installation
⚠️ **Please read the [FAQ](https://github.com/AF-1/lms-dynamicplaylistcreator#faq) *before* installing this plugin.**<br>

Add the repository URL below at the bottom of *LMS* > *Settings* > *Plugins* and click *Apply*:<br><br>
[**https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml**](https://raw.githubusercontent.com/AF-1/lms-dynamicplaylistcreator/main/repo.xml)
<br><br><br><br>


## Report a bug
If you think that you've found a bug, open an [**issue here on GitHub**](https://github.com/AF-1/lms-dynamicplaylistcreator/issues) and fill out the ***Bug report* issue template** including as much information as possible.<br>
Please post bug reports on **GitHub only**.
<br><br><br><br>


## FAQ

<details><summary>»<b>Can I import my custom dynamic playlists from the <i>SQLPlayList</i> plugin?</b>«</summary><br><p>
No, you <b>can't</b> import or migrate dynamic playlist definitions from the <i>SQLPlayList</i> plugin to <i>Dynamic Playlist <b>Creator</b></i>. They are based on templates which are different from the ones that DPLC uses.
</p></details><br>

<details><summary>»<b>Can I manually <i>edit the SQLite statement</i> of my dynamic playlists in DPLC?</b>«<br>&nbsp;&nbsp;&nbsp;&nbsp;»<b>What does the <i>export</i> button do?</b>«</summary><br><p>
The target group for this plugin is users who want to quickly and easily create custom dynamic playlists using <b>only</b> templates and <b>not</b> working directly with SQLite statements. Accordingly, DPLC does <b>not include the option to manually edit SQLite statements</b> in a tiny text area.<br><br>

Users familiar with SQLite can <b>use the <i>export</i> button</b> to <b>permanently move</b> a dynamic playlist <i>currently managed by DPLC</i> to the <i>Dynamic Playlists</i> plugin, i.e. its folder for custom dynamic playlists called <b>DPL-custom-lists</b>. There you can edit it like any other custom dynamic playlist with your favorite code editor.<br>
Moved dynamic playlists are removed from, i.e. no longer managed by DPLC.
</p></details><br>

<details><summary>»<b>What are the files in the <i>DynamicPlaylistCreator</i> folder for? Can I edit them?</b>«</summary><br><p>
When you create or edit and then <i>save</i> a custom dynamic playlist, DPLC will create 2 files in the <i>DynamicPlaylistCreator</i> folder (default location in the LMS playlists folder, can be changed in the plugin settings):<br>
the file with the <b>customvalues.xml</b> extension contains the (template) values you selected for this dynamic playlist. It allows you to edit or update your custom dynamic playlist in DPLC at a later time.<br>
In addition, DPLC will <b>always</b> save your custom dynamic playlist as an SQLite statement (file extension: <b>sql</b>) because <i>Dynamic Playlists</i> searches the DPLC custom folder for them.<br><br>
<b>Do <u><i>not</i></u> manually move or edit any of these files!</b> DPLC will overwrite the changes. Or worse, your custom dynamic playlist will no longer work.
</p></details><br>

<details><summary>»<b>Why is the <i>Play button</i> to <i>start</i> dynamic playlists directly from the DPLC list of created dynamic playlists not displayed for <i>all</i> dynamic playlists?</b>«</summary><br><p>
You can <b>only</b> start dynamic playlists directly in DPLC that do <b>not ask for user input when started</b>. DPLC does not contain code to handle user-input parameters. To simplify the maintenance and updating of the plugin, I decided to create DPLC as a sort of dynamic playlist construction kit without duplicating any code from the <i>Dynamic Playlists</i> plugin.
</p></details><br>

<details><summary>»<b>Which plugins does DPLC work with?</b>«</summary><br><p>
It works with <a href="https://github.com/AF-1/lms-dynamicplaylists#faq"><b>Dynamic Playlists 4</b></a>, <a href="https://github.com/AF-1/lms-alternativeplaycount"><b>Alternative Play Count</b></a> and <a href="https://github.com/AF-1/lms-customskip#custom-skip"><b>Custom Skip 3</b></a>.<br><b>CustomScan</b>: could work, not tested. Compatibility not guaranteed, not supported by me.
</p></details><br>

<details><summary>»<b>In some DPLC templates there's no option to set a <i>track limit</i> and no “do not repeat” setting.</b>«</summary><br><p>
Dynamic playlists that <b>use the LMS cache</b> cannot have a track limit because <i>Dynamic Playlists</i> <b>4</b> will load <b>all</b> track IDs matching the active dynamic playlist's search parameters into the cache using a single initial database query. The cached track ID list should not have duplicates, hence no “do not repeat” option. DPL 4 will add small batches of tracks from this cached list to the players's current playlist. The number of new unplayed tracks to be added per batch can be set in the DPL settings. It's a global setting for all dynamic playlists (except album dynamic playlists which should add complete albums).
</p></details><br>

<details><summary>»<b>Can I use <i>Dynamic Playlist Creator</i> and <i>SQLPlayList</i> at the same time?</b>«</summary><br><p>
<i>Dynamic Playlists</i> version <b>4</b> ignores SQLPlayList. There's no benefit but no harm either in keeping it installed.
</p></details><br>

<details><summary>»<b>Can you translate DPLC into my language?</b>«</summary><br><p>
This plugin will not be localized because parameter names and value names are baked into the templates. And a halfway localized version is worse than a non-localized one.
</p></details><br>
<br>

[^1]:inspired by and based on Erland's SQLPlayList