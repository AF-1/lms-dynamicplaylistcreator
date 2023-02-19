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

You should be able to install **Dynamic Playlist Creator** from the LMS main repository (LMS plugin library):<br>**LMS > Settings > Plugins**.<br>

If you want to test a new patch that hasn't made it into a release version yet or you need to install a previous version, you'll have to [install the plugin manually](https://github.com/AF-1/sobras/wiki/Manual-installation-of-LMS-plugins).

It usually takes a few hours for a *new* release to be listed on the LMS plugin page.
<br><br><br><br>


## Reporting a new issue

If you want to report a new issue, please fill out this [**issue report template**](https://github.com/AF-1/lms-dynamicplaylistcreator/issues/new?template=bug_report.md&title=%5BISSUE%5D+).
<br><br><br><br>


## FAQ

<details><summary>»<b>How do I <i>create</i> custom dynamic playlists?</b>«</summary><br><p>

- Go to <i>LMS home menu</i> > <i>Extras</i> > <i>Dynamic Playlist Creator</i> > <i>Create new dynamic playlist</i>.<br>

- Depending on the focus of your new dynamic playlist, <b>select a template</b>. The <i>Random Tracks - Advanced</i> template with its many options is a good starting point.<br>

- Enter a <b>name</b>, set the <b>parameters</b> you want to use and then <b>save</b> it. That's it.<br><br>

It <b>takes a couple of seconds</b> for the <i>Dynamic Playlists</i> plugin to start updating the list of available dynamic playlists and your new dynamic playlist to show up there. If you don't see your dynamic playlists listed, you can force a refresh of available dynamic playlists by (re)calling the <i>Dynamic Playlists</i> menu from the <i>LMS home</i> menu.
</p></details><br>

<details><summary>»<b>How can I <i>edit</i> custom dynamic playlists I've created with this plugin?</b>«</summary><br><p>
<i>Dynamic Playlist Creator</i> displays a list of all dynamic playlists that you have created with this plugin.<br>If you want to change the name of your dynamic playlist or some parameters, click on the <b>Edit</b> button next to the playlist's name, make your changes and save it. After a couple of seconds, the Dynamic Playlist plugin will update its list of available dynamic playlists and pick up the changes you just made.</p></details><br>

<details><summary>»<b>Can I manually <i>edit the SQLite statement</i> of my dynamic playlists in DPLC?</b>«<br>&nbsp;&nbsp;&nbsp;&nbsp;»<b>What does the <i>export</i> button do?</b>«</summary><br><p>
The target group for this plugin is users who want to quickly and easily create custom dynamic playlists using <b>only</b> templates and <b>not</b> working directly with SQLite statements. Accordingly, DPLC does <b>not include the option to manually edit SQLite statements</b> in a tiny text area.<br><br>

Users familiar with SQLite can <b>use the <i>export</i> button</b> to <b>permanently move</b> a dynamic playlist <i>currently managed by DPLC</i> to the <i>Dynamic Playlists</i> plugin, i.e. its folder for custom dynamic playlists called <b>DPL-custom-lists</b>. There you can edit it like any other custom dynamic playlist with your favorite code editor.<br>
Moved dynamic playlists are removed from and no longer managed by DPLC.<br><br>Please note: the <b>export</b> button is <b>disabled by default</b> and can be enabled in DPLC's settings.</p></details><br>

<details><summary>»<b>What are the files in the <i>DynamicPlaylistCreator</i> folder for? Can I edit them?</b>«</summary><br><p>
When you create or edit and then <i>save</i> a custom dynamic playlist, DPLC will create 2 files in the <i>DynamicPlaylistCreator</i> folder (default location in the LMS playlists folder, can be changed in the plugin settings):<br>
the file with the <b>customvalues.xml</b> extension contains the (template) values you selected for this dynamic playlist. It allows you to edit or update your custom dynamic playlist in DPLC at a later time.<br>
In addition, DPLC will <b>always</b> save your custom dynamic playlist as an SQLite statement (file extension: <b>sql</b>) because <i>Dynamic Playlists</i> searches the DPLC custom folder for them.<br><br>
<b>Do <u><i>not</i></u> manually move or edit any of these files!</b> DPLC will overwrite the changes. Or worse, your custom dynamic playlist will no longer work.
</p></details><br>

<details><summary>»<b>Why is the <i>Play button</i> not displayed for <i>all</i> dynamic playlists?</b>«<br>&nbsp;&nbsp;&nbsp;&nbsp;»<b>The <i>Play</i> button is not working for new dynamic playlists.</b>«</summary><br><p>
The <b>play</b> button is <b>disabled by default</b> and has to be enabled in DPLC's settings first.<br>
You can <b>only</b> start dynamic playlists directly in DPLC that do <b><u>not</u> ask for user input when started</b>. DPLC does not contain code to handle user-input parameters. To simplify the maintenance and updating of the plugin, I decided to create DPLC as a sort of dynamic playlist construction kit without duplicating any code from the <i>Dynamic Playlists</i> plugin.<br><br>After you have created a <b>new</b> dynamic playlist that does not ask for user input, please wait a few seconds before you try to start it with the <i>Play</i> button. <i>Dynamic Playlists</i> needs a moment to update the list of available dynamic playlists.<br><br>Starting dynamic playlists without user-input parameters in DPLC is just a quick way to test a dynamic playlist. The <i>Dynamic Playlists</i> plugin is still where you start your mixes, not DPLC.
</p></details><br>

<details><summary>»<b>Can I import my custom dynamic playlists from the <i>SQLPlayList</i> plugin?</b>«</summary><br><p>
No, you <b>can't</b> import or migrate dynamic playlist definitions from the <i>SQLPlayList</i> plugin to <i>Dynamic Playlist <b>Creator</b></i>. They are based on templates which are different from the ones that DPLC uses.
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