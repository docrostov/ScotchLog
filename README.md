# ScotchLog
This is a Kingdom of Loathing script by me (Captain Scotch (#437479) -- DocRostov#7004 on Discord) intended to generate run logs from ascensions played by KoL players. The goal of this project is to create a more advanced version of the output from CKB's RunLogSum function, that also includes more information in the post-run session report as well as improved handling for turn-by-turn special actions. I also added a ton more comments. 

To install:
`svn checkout https://github.com/docrostov/ScotchLog/branches/master/KoLmafia`

## Output
Depending on your inputs for mafioso/resources, this script will generate 1-3 files. The files are formatted as follows:

  - **The Mafioso File** -- A simple concatenation of every day of the captured run, for use with [https://kolmafioso.app/](KoLMafioso.app). Naming convention is *USERNAME_LASTDAY_DAYCOUNT_mafioso.txt*
  - **The RunLog** -- A tab separated file where each row represents a turn or a turn-like object in your ascension, capturing things like how the combat went, what items got dropped, etc. Naming convention is *USERNAME_LASTDAY_DAYCOUNT_TURNCOUNT.tsv*
  - **The RunReport** -- Another tab separated file that includes summaries of turns/actions for each location, familiar usage, and usage of some of your IOTM-type resources and pulls. Naming convention is *USERNAME_LASTDAY_DAYCOUNT_TURNCOUNT_runReport.tsv*

## Supported Commands
**parse** - Tries to parse a log. Proper syntax & an example:
> `ScotchLog parse` (NOTE: Grabs your most recent run. This should always work, or tell you why it didn't.)

> `ScotchLog parse [ENDDATE] [NUMBEROFDAYS]` (NOTE: This feature is currently in beta. Might break!)

> EXAMPLE -> `ScotchLog parse 20200614 3`

**help** - Brings up a help screen

**links** - Brings up a series of useful KOL links for the user

**mafioso** - Toggles mafioso.txt output, for use with [https://kolmafioso.app/](KoLMafioso.app). Default is 'nosave'. Syntax:
> `ScotchLog mafioso save` (If you want mafioso output.)

> `ScotchLog mafioso nosave` (If you don't.)

**resources** - Toggles resource tracking CSV output. Default is 'save'. Syntax:
> `ScotchLog resources save` (If you want resource output.)

> `ScotchLog resources nosave` (If you don't.)
