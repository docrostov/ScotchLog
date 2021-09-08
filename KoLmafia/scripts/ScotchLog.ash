script <ScotchLog>;
since r20267;

string __scotchLog_version = "0.95";

// ==============================================================
// ------------------------ INTRODUCTION ------------------------
// ==============================================================

// This log parser is an attempt to build on CKB's already very
//   good runLogSum function. There were a few structural changes 
//   I made here to be more speed-ascension-relevant. I used my
//   own Python parser for the skeleton of the overall build &
//   CKB's parser to help me understand proper ASH text parsing  

// RunLogSum.ash by ckb1
//   |--- https://kolmafia.us/showthread.php?22963-RunLogSummary

// Run-Log-Parser by Captain Scotch
//   |--- https://github.com/docrostov/KOL-Log-Parser/

// ==============================================================
// ~~~~~~~~~~~~~~~~~~~~~~~~~ TO-DO LIST ~~~~~~~~~~~~~~~~~~~~~~~~~
// ==============================================================
//   - Figure out a way to sort the runReport's loc/fam output
//   - Add handling for between-turn stuff I want to snag
//       |-- Bastille is a main thing here
//   - Add handling for things I want to actually remove
//       |-- Beachcombing data; pretty unnecessary
//       |-- Resting data, I think?
//   - Create a relay overlay
//   - Support for different usernames 

// ==============================================================
// ~~~~~~~~~~~~~~~~~~~~~~~~ KNOWN ISSUES ~~~~~~~~~~~~~~~~~~~~~~~~
// ==============================================================
//   - When multiple heists happen in the same turn, it doesn't increment the items dropped properly though it does increment heist usage the fam log
//   - Monsters macro'd into still have "a" & "!" next to their names
//   - Due to how session_logs() works, I have no way of capturing days where someone didn't open mafia.
//   - I have -no- idea how, but the loc/fam summaries appear to be missing exactly 4 turns on every run. >:|
// ==============================================================

// Instantiate the new log
buffer rLog;

// Instantiate the "fake turn" buffer
buffer fLog;

// Instantiate the "resources" buffer
buffer runReport;

// Set up name as a variable so you don't constantly call "my_name()",
//   and so that I can later implement parsing the logs of others in
//   your session log directory like I had in the python parser.
string myName = my_name();

// Flag that turns on CLI print statements if I'm testing stuff
boolean testing = true;

void outputHelp(){
    // Putting the "help" output up top so I remember to update it.
    print_html("<strong>========= SCOTCH-LOG-PARSER v" + __scotchLog_version+" =========</strong>");
	print_html("<strong>parse</strong> - Tries to parse a log. Proper syntax & an example:");
	print_html("    >>> <font color='green'>ScotchLog parse</font> (NOTE: Grabs your most recent run.)");
	print_html("    >>> <font color='green'>ScotchLog parse [ENDDATE] [NUMBEROFDAYS]</font> (NOTE: This feature is currently in beta. Might break!)");
	print_html("    >>> EXAMPLE -> <font color='gray'>ScotchLog parse 20200614 3</font>");
	print_html("");
	print_html("<strong>help</strong> - Brings up this screen!");
	print_html("");
	print_html("<strong>links</strong> - Brings up a series of useful KOL links for the user");
	print_html("");
	print_html("<strong>mafioso</strong> - Toggles mafioso.txt output. Default is 'nosave'. Syntax:");
	print_html("    >>> <font color='green'>ScotchLog mafioso save</font> <font color='gray'>(If you want mafioso output.)</font> ");
	print_html("    >>> <font color='green'>ScotchLog mafioso nosave</font> <font color='gray'>(If you don't.)</font> ");
	print_html("");
	print_html("<strong>resources</strong> - Toggles resource tracking CSV output. Default is 'save'. Syntax:");
	print_html("    >>> <font color='green'>ScotchLog resources save</font> <font color='gray'>(If you want resource output.)</font> ");
	print_html("    >>> <font color='green'>ScotchLog resources nosave</font> <font color='gray'>(If you don't.)</font> ");
}

void outputLinks(){
    // Putting the "links" output up top so I remember to update it.
    print_html("<strong>========= SCOTCH-LOG-PARSER v" + __scotchLog_version+" =========</strong>");
	print_html("");
    print_html("<a href=\"https://discord.gg/tbUCRT5\"><strong>The Ascension Speed Society Discord Server</strong></a>");
	print_html("    >>> <font color='purple'>Speed ascension server with helpful tips & tricks</font>");
	print_html("");
    print_html("<a href=\"https://kolmafioso.app/\"><strong>KOL Mafioso</strong></a>");
	print_html("    >>> <font color='purple'>An alternate parser; upload the _mafioso files this generates for a pretty non-spreadsheet log!</font>");
	print_html("");
    print_html("<a href=\"https://kolmafia.us/showthread.php?22963-RunLogSummary\"><strong>CKB's RunLogSum</strong></a>");
	print_html("    >>> <font color='purple'>An alternate parser; code was the inspiration/heavily used for this parser.</font>");
	print_html("");
    print_html("<a href=\"https://github.com/docrostov/KOL-Log-Parser/\"><strong>Captain Scotch's Run-Log-Parser</strong></a>");
	print_html("    >>> <font color='purple'>An alternate parser; I built this one first, because I'm considerably better @ python.</font>");

}

// ===============================================================
// -------------------------- RAW DATA! --------------------------
// ===============================================================

static string [string] banisherList = {
    // List of all banisher strings, & whether they're items or 
    //   skills. Sources in comments for personal reference.

                                                      // PERMASTANDARD & PATHS =========
    "BATTER UP"                           : "skill",  // seal clubber skill; removing ! tho
    "SHOW THEM YOUR RING"                 : "skill",  // mafia middle finger ring
    "Harold's bell"                       : "item",   // once/ascension quest reward
    "BALEFUL HOWL"                        : "skill",  // PATH: dark gyffte
    "ULTRA SMASH"                         : "skill",  // PATH: path of the plumber
    "BANISHING SHOUT"                     : "skill",  // PATH: avatar of boris
    "PEEL OUT"                            : "skill",  // PATH: avatar of sneaky pete
    "WALK AWAY FROM EXPLOSION"            : "skill",  // PATH: avatar of sneaky pete
    "smoke grenade"                       : "item",   // PATH: avatar of sneaky pete
    "CURSE OF VACATION"                   : "skill",  // PATH: avatar of ed the undying
    "BEANCANNON"                          : "skill",  // PATH: avatar of WOL
    "HOWL OF THE ALPHA"                   : "skill",  // PATH: zombie slayer
    "THUNDER CLAP"                        : "skill",  // PATH: heavy rains
    "classy monkey"                       : "item",   // PATH: class act
    "dirty stinkbomb"                     : "item",   // PATH: KOLHS
    "deathchucks"                         : "item",   // PATH: KOLHS
    "B. L. A. R. T. SPRAY (WIDE)"         : "skill",  // PATH: Wildfire

                                                      // BANISHER SKILLS via IOTM ======
    "CREEPY GRIN"                         : "skill",  // 2007 vivala mask
    "GIVE YOUR OPPONENT THE STINKEYE"     : "skill",  // 2010 stinky cheese
    "TALK ABOUT POLITICS"                 : "skill",  // 2013 pantsgiving
    "LICORICE ROPE"                       : "skill",  // 2016 gingerbread city
    "SNOKEBOMB"                           : "skill",  // 2016 snojo
    "KGB TRANQUILIZER DART"               : "skill",  // 2017 KGB
    "SPRING-LOADED FRONT BUMPER"          : "skill",  // 2017 asdon-martin
    "BREATHE OUT"                         : "skill",  // 2017 space jellyfish
    "THROW LATTE ON OPPONENT"             : "skill",  // 2018 latte lovers member card
    "REFLEX HAMMER"                       : "skill",  // 2019 doctor bag
    "SABER BANISH"                        : "skill",  // 2019 force saber; this is a custom remapping!!
    "FEEL HATRED"                         : "skill",  // 2021 emotion chip
    "SHOW YOUR BORING FAMILIAR PICTURES"  : "skill",  // 2021 familiar scrapbook
	
                                                      // BANISHER ITEMS via IOTM =======
    "divine champagne popper"             : "item",   // 2008 libram of divine favors
    "crystal skill"                       : "item",   // 2011 tome of clip art
    "Winifred's whistle"                  : "item",   // 2012 blavious kloop
    "Louder Than Bomb"                    : "item",   // 2013 smith's tome
    "ice house"                           : "item",   // 2014 winter garden
    "tennis ball"                         : "item",   // 2016 haunted doghouse
    "Daily Affirmation: Be a Mind Master" : "item",   // 2017 new-you affirmations
    "tryptophan dart"                     : "item",   // 2018 mechanical elf
    "human musk"                          : "item",   // 2019 red-nosed snapper
};

static string [string] freeKillList = {
    // List of all the freeKill strings, & whether they're
    //   items or skills. Sources in comments.
                                                      // PATH & PERMASTANDARD INSTAKILLS
    "glark cable"                         : "item",   // 5/day freekill, red zeppelin
    "LIGHTNING STRIKE"                    : "skill",  // PATH: heavy rains

                                                      // FREEKILL SKILLS via IOTM ======
    "SHATTERING PUNCH"                    : "skill",  // 2016 snojo
    "FIRE THE JOKESTER'S GUN"             : "skill",  // 2016 batfellow
    "GINGERBREAD MOB HIT"                 : "skill",  // 2016 gingerbread city
    "MISSILE LAUNCHER"                    : "skill",  // 2017 asdon-martin
    "CHEST X-RAY"                         : "skill",  // 2019 lil doc bag
    "SHOCKING LICK"                       : "skill",  // 2021 power seed

                                                      // FREEKILL ITEMS via IOTM =======
    "superduperheated metal"              : "item",   // 2015 that 70s volcano
    "power pill"                          : "item",   // 2015 yellow puck
    "replica bat-oomerang"                : "item",   // 2016 batfellow
    "Daily Affirmation: Think Win-Lose"   : "item",   // 2017 new-you affirmations
    "powdered madness"                    : "item",   // 2019 red-nosed snapper
};

static string [string] sniffList = {
    // List of all the sniffing strings, & whether they're
    //   items or skills. Sources in comments. Note that at
    //   initial construction of this parser they're all
    //   skills; I just want to maintain matching syntax.
                                                      // PERMASTANDARD & PATHS =========
    "TRANSCENDENT OLFACTION"              : "skill",  // bounty hunting reward
    "GET A GOOD WHIFF OF THIS GUY"        : "skill",  // skill attained via nosy nose fam
    "PERCEIVE SOUL"                       : "skill",  // PATH: dark gyffte
    "MAKE FRIENDS"                        : "skill",  // PATH: avatar of sneaky pete

                                                      // IOTM-BASED SNIFFS =============
    "GALLAPAGOSIAN MATING CALL"           : "skill",  // bounty hunting reward
    "OFFER LATTE TO OPPONENT"             : "skill",  // 2018 latte lovers member card

};

static string [string] copyList = {
    // List of all the copier strings, & whether they're
    //   items or skills. Sources in comments.

                                                      // PERMASTANDARD & PATHS =========
    "4-d camera"                          : "item",   // craftable via beer lens & box

                                                      // IOTM-BASED COPIERS ============
    "Spooky Putty sheet"                  : "item",   // 2009 spooky putty
    "Rain-Doh black box"                  : "item",   // 2012 rain-doh
    "BADLY ROMANTIC ARROW"                : "skill",  // 2011 obtuse angel
    "WINK AT"                             : "skill",  // 2013 reanimator
    "print screen button"                 : "item",   // 2016 intergnat
    "DIGITIZE"                            : "skill",  // 2016 source terminal
    "LOV Enamorang"                       : "item",   // 2017 LOV tunnel
    "LECTURE ON RELATIVITY"               : "skill",  // 2019 pocket professor
    "BACK-UP TO YOUR LAST ENEMY"          : "skill",  // 2021 backup camera


};

static string [string] statDictionary = {
    // List of substrings to look for when parsing stat
    //   gain strings. Syntax is [match]:[statType]

    // Muscle strings 
    "Beefiness"         :"mus",
    "Fortitude"         :"mus",
    "Muscleboundness"   :"mus",
    "Strengthliness"    :"mus",
    "Strongness"        :"mus",
    // Myst strings
    "Enchantedness"     :"mys",
    "Magicalness"       :"mys",
    "Mysteriousness"    :"mys",
    "Wizardliness"      :"mys",
    // Mox strings
    "Cheek"             :"mox",
    "Chutzpah"          :"mox",
    "Roguishness"       :"mox",
    "Sarcasm"           :"mox",
    "Smarm"             :"mox",
};

static string [string] runList = {
    // List of all freeRun strings. These are a little annoying,
    //   actually! Some of them are -really- context dependent.
    //   But in the interest of being explicit I am trying to
    //   make the code able to capture runs properly. It is
    //   possible to use more than 1 free run in a turn, if you
    //   use things like tattered scraps, also. This list 
    //   includes free-run banishers as well. This list does 
    //   NOT include bander/boots runs, which are a separate
    //   can of worms relating to currFam.

                                                      // BANISHERS THAT ARE RUNS ======
    "SHOW THEM YOUR RING"                 : "skill",  // mafia middle finger ring
    "BALEFUL HOWL"                        : "skill",  // PATH: dark gyffte
    "PEEL OUT"                            : "skill",  // PATH: avatar of sneaky pete
    "dirty stinkbomb"                     : "item",   // PATH: KOLHS
    "deathchucks"                         : "item",   // PATH: KOLHS
    "CREEPY GRIN"                         : "skill",  // 2007 vivala mask
    "GIVE YOUR OPPONENT THE STINKEYE"     : "skill",  // 2010 vivala mask
    "SNOKEBOMB"                           : "skill",  // 2016 snojo
    "KGB TRANQUILIZER DART"               : "skill",  // 2017 KGB
    "SPRING-LOADED FRONT BUMPER"          : "skill",  // 2017 asdon-martin
    "BREATHE OUT"                         : "skill",  // 2017 space jellyfish
    "THROW LATTE ON OPPONENT"             : "skill",  // 2018 latte lovers member card
    "REFLEX HAMMER"                       : "skill",  // 2019 doctor bag
    "divine champagne popper"             : "item",   // 2008 libram of divine favors
    "Winifred's whistle"                  : "item",   // 2012 blavious kloop
    "Louder Than Bomb"                    : "item",   // 2013 smith's tome
    "tennis ball"                         : "item",   // 2016 haunted doghouse
    "human musk"                          : "item",   // 2019 red-nosd snapper
    "B. L. A. R. T. SPRAY (WIDE)"         : "skill",  // PATH: Wildfire
    "FEEL HATRED"                         : "skill",  // 2021 emotion chip
    "SHOW YOUR BORING FAMILIAR PICTURES"  : "skill",  // 2021 familiar scrapbook
	
                                                      // PATH & IOTM FREE-RUNS =========
    "ENSORCEL"                            : "skill",  // PATH: dark gyffte
    "giant eraser"                        : "item",   // PATH: kolhs
    "SUMMON MAYFLY SWARM"                 : "skill",  // 2008 mayfly bait necklace
    "wumpus-hair bolo"                    : "item",   // 2009 sandworm agua de vida zone
    "glob of Blank-Out"                   : "item",   // 2010 crimbo reward
    "peppermint parasol"                  : "item",   // 2011 peppermint garden

                                                      // LIMITED USE FREE-RUNS =========
    "Mer-kin pinkslip"                    : "item",   // 100% freerun; mer-kin only
    "cocktail napkin"                     : "item",   // 100% freerun; clingy pirate only
    "bowl of scorpions"                   : "item",   // 100% freerun; drunk pygmy only
    "T.U.R.D.S. Key"                      : "item",   // 100% freerun; ghosts only
    "short writ of habeas corpus"         : "item",   // 100% freerun; pygmys only
    "windicle"                            : "item",   // 100% freerun; piraterealm only

                                                      // ALL OTHER FREE-RUNS ===========
    "fish-oil smoke bomb"                 : "item",   // 100% freerun; AT nemesis quest item
    "green smoke bomb"                    : "item",   //  90% freerun; via green op soldier
    "tattered scrap of paper"             : "item",   //  50% freerun; via bookbat
    "GOTO"                                : "item",   //  30% freerun; via BASIC elemental


};

static string [string] kingFreedList ={
    "Took choice 1089/30: Perform Service": "CS",
    "Took choice 1054/1: Yep"             : "ED",
    "Freeing King Ralph"                  : "default"
};


static string [string] runStartList ={
    "tutorial.php"                        : "firstRun",
    "Beginning New Ascension"             : "default"
};

// New record types for this parser's run report

record pulls {
    int day;
    int turn;
    int num;
    string pull;
};

record pizza {
    int day;
    int turn;
    int advs;
    int mus;
    int mys;
    int mox;
    string ingredients;
    string effectGiven;
    string itemsDropped;
};

record pills {
    int day;
    int turn;
    string pillType;
};

record saber {
    int day;
    int turn;
    string saberMonster;
    string saberType;
};

// Record for locLog
record locationLog {
    int advs;
    int freeTurns;
    int noncoms;
    int banishes;
    int freekills;
    int spits;
    int copiers;
    int runs;
};

// Record for famLog
record familiarLog {
    int turns;
    int actions;
    string actionType;
};

// ===============================================================
// ---------------------- HELPER FUNCTIONS! ----------------------
// ===============================================================

int grabNumber(string s){
    // Uses matchers to grab first # from a string. Generally I 
    //   don't like how unreadable regex-littered scripts become,
    //   which is why I barely use regex at all in this parser.
    matcher numMatcher = create_matcher("\\d+",s);
    if (numMatcher.find()){
        return numMatcher.group(0).to_int();
    } else {
        return 0;
    }
}

void submitToLog(string[int] sList, buffer buffy){
    // Function allowing me to just submit a list of strings to
    //   the buffer that represents one of two things -- either
    //   the new log object, or the consumption buffer.
    foreach x in sList{
        buffy.append(sList[x]);
        buffy.append("\t");
    }
    buffy.append("\n");
}

int isSpecial(string s, string sType, string[string] sList){
    // Function for determining if the item or skill used generated
    //   a special flag; sniffs, banishes, & freekills currently 
    //   supported using the reference lists up top.

    foreach x,typ in sList{
        if (x==s && typ==sType){
            return 1;
        }
    }

    // Only hits this 0 if none were true.
    return 0;
}

boolean isRunner(familiar f){
    // Very simple helper to establish if you are running
    //   a free-run fam. Used for "casts RETURN" parsing.

    if (f==$familiar[ Frumious Bandersnatch ]){  return true;}
    if (f==$familiar[ Pair of Stomping Boots ]){ return true;}

    // If we didn't hit the right fams, it's false.
    return false;
}

boolean isFake(string s){
    // Tests to see if the string matches any of my "fake" 
    //   generated turns. Currently, when I instantiate a
    //   "fake" turn, I include a bit at the beginning that
    //   identifies exactly what kind of turn it is.

    if (contains_text(s, "CONSUME:")){    return true; }
    if (contains_text(s, "PILLKEEPER:")){ return true; }
    if (contains_text(s, "HEIST: Stealing an item!")){ return true; }

    // If it didn't hit the "fake" conditions above, it has 
    //   presumably given me its heart & made it real. We 
    //   won't forget about it. :'-0
    return false;
}

int statChange(string s, string sType){
    // Function for grabbing substat changes. KOL uses a
    //   series of known word buckets for mus/mys/mox; this
    //   compares against those words & snags the #. Tried
    //   to align structure with "isSpecial".

    foreach x, typ in statDictionary {
        if (contains_text(s, x) && sType == typ){
            return grabNumber(s);
        }
    }

    // Return 0 if it didn't get a match.
    return 0;
}

int daysFromToday( string usersDate ){
    // A truly dump truck ass function to calculate # of days 
    //   a YYYYMMDD date string is from today's date. Help 
    //   from Phillammon was crucial in refactoring this to
    //   be significantly less dump truck ass.

    string startDate = now_to_string("yyyyMMdd");

    // Some simple error checking
    if (length(usersDate) != 8){
        print("ERROR: input date ("+usersDate+") is not 8 characters.","red");
        return 0; 
    } else if (usersDate.to_int() > startDate.to_int()) {
        print("ERROR: input date ("+usersDate+") is in the future, not the past.","red");
        return 0;
    } else if (usersDate.to_int() == 0){
        print("ERROR: could not convert date string ("+usersDate+") to date. Is it yyyyMMdd?","red");
        return 0;
    } else if (usersDate.to_int() < 20050128) {
        print("ERROR: you're trying to grab a log from before KOLMafia existed ("+usersDate+"). Calm down, fam.","red");
        return 0;
    }

    // This construction generates how many days into a year a date is.
    //   IE, for 8-7-2020, it correctly says that's 220 days into the
    //   year. That simplifies this calculation a lot!
    int targetDay = to_int(format_date_time("yyyyMMdd",usersDate,"DD"));
    int startDay = to_int(format_date_time("yyyyMMdd",startDate,"DD"));
    int targetYear = to_int(format_date_time("yyyyMMdd",usersDate,"yyyy"));
    int startYear = to_int(format_date_time("yyyyMMdd",startDate,"yyyy"));
    
    // Unfortunately, it doesn't handle leap years. So, Phill wrote this!
    int interveningYears = startYear - targetYear;
    // I am so sorry about the following lines. - Phill
    // Stop apologizing, it's good fam. - Scotch
    int interveningLeapDays = to_int(startYear / 4) - to_int(targetYear / 4);
    if ((targetYear % 4) == 0){ interveningLeapDays += 1;}
    if ((startYear % 4) == 0) { interveningLeapDays -= 1;} // -= is such a weird sign
    
    // And then it just becomes a case of simple addition.
    int daysbetween = 365 * interveningYears + interveningLeapDays + startDay - targetDay;

    return daysBetween;
    
}

string strip(string input) {
    // This function is by "worthawholebean" on the KOLmafia
    //   forum thread for CKB's parser. Using it to try and
    //   make this work on both windows & mac.
    matcher start = create_matcher("^\\s+", input);
    input = start.replace_all("");
    matcher end = create_matcher("\\s+$", input);
    return end.replace_all("");
}

// ===============================================================
// ----------------------- CORE FUNCTIONS! -----------------------
// ===============================================================

void parseLog(string runLog, string fName) {

    // =========================================================
    // -- NOTE: This function deviates a *lot* from RunLogSum!
    // =========================================================

    // This is the collected string for submitting to the runLog.
    //   I like using the int index for this so that I know exactly
    //   what column everything -should- be.
    string[int] eventLog;

    // Also, let's make a similar log for "fake" stuff. Basically 
    //   everything where I have made synthetic turns, like 
    //   pillkeeper & consumption stuff. 
    string[int] fakeLog;

    // Start the log with the overall header
    eventLog[1]  = 'day';
    eventLog[2]  = 'turnSpent';
    eventLog[3]  = 'free?';
    eventLog[4]  = 'location';
    eventLog[5]  = 'encounterName';
    eventLog[6]  = 'familiar';
    eventLog[7]  = 'items';
    eventLog[8]  = 'meat';
    eventLog[9]  = 'rounds';
    eventLog[10] = 'mus';
    eventLog[11] = 'mys';
    eventLog[12] = 'mox';
    eventLog[13] = 'advsGained';
    eventLog[14] = 'effectsGained';
    eventLog[15] = 'itemsUsed';
    eventLog[16] = 'skillsUsed';
    eventLog[17] = 'freeRun?';
    eventLog[18] = 'banish';
    eventLog[19] = 'freeKill';
    eventLog[20] = 'sniff';
    eventLog[21] = 'spit';
    eventLog[22] = 'copy';
    eventLog[23] = 'macroFrom';

    // Submit the header to the log
    submitToLog(eventLog, rLog);

    // Like my python parser, I am making bunch of referential 
    //   variables for the script to update as it parses through
    //   a user's log. These are the "current status" variables.
    familiar currFam = $familiar[ None ];
    int currDay   = 0;

    // Mafia logs always start at turn 1.
    int currTurn  = 1;
    int prevTurn  = 1;

    // These are the static "information collection" variables
    pulls [int] runPulls;
    int numPulls = 0;
    pills [int] pillsUsed; // pillkeeper tracking
    pizza [int] pizzaUsed; // pizza tracking; may expand to better record?
    saber [int] saberUsed; // saber tracking
    
    // Separate location/familiar parsers
    familiarLog [familiar] famLog;
    locationLog [string] locLog;

    // These are the combat-specific current status variables
    string s = ""; 
    boolean freeTurn = false;
    int combatRound = -1;
    int mus = 0;
    int mys = 0;
    int mox = 0;
    int meat = 0;
    int advGain = 0;
    string itemsUsed = "";
    string skills = "";
    string effectsGained = "";
    string itemsGained = "";
    string origMonster = "";
    string currLoc = "N/A";
    string newLoc = "N/A";  // used for the zone replacement
    string encounterTitle = "N/A";
    int freeRun = 0;
    string roundStmt = "";
    string pizzaIngredients = "";

    // Combat counters for special events
    int banished = 0;
    int freekill = 0;
    int sniff    = 0;
    int spit     = 0;
    int copier   = 0;

    // The parser uses this so that it knows if it's currently 
    //   parsing a turn or not for certain information capture.
    boolean inTurn = false;

    string[int] splitLog = split_string(runLog,"\n");    // Splitting your runlog by newlines

    // This is the for-loop iterator that travels through the 
    //   log, line by line. Isn't perfect, but it works.

    foreach l in splitLog {
        // Stripping out whitespace characters w/ bean's function.
        string currLine = strip(splitLog[l]);
        //print(currLine,"gray");

        if (length(currLine) > 3){
            // In order to handle consumption, I am transforming lines where
            //   the user has consumed items into "turn-like" lines that (in
            //   turn) start the parser.

            // Just making this variable so the line is more readable.
            string cString = substring(currLine, 0, 3);

            // Conversion into a turn-like
            if (cString == "eat" || cString == "dri" || cString == "che"){
                currLine = "["+currTurn.to_string()+"] CONSUME: "+currLine;
            }

            // I am also transforming a few choice adventures.
            if (length(currLine) > 16){

                // Pillkeeper is choice 1395!
                if (contains_text(currLine,'Took choice 1395')){
                    // Adding a row for pillkeeper turns!
                    string pillLine = "PILLKEEPER: "+substring(currLine,20);

                    // Populate the pillkeeper map
                    pillsUsed[count(pillsUsed)] = new pills (currDay, currTurn, substring(currLine,20));
                    
                    // Change the line string
                    currLine = "["+currTurn.to_string()+"] "+pillLine;
                }

                // Saber is choice 1387!
                if (contains_text(currLine,'Took choice 1387')){

                    // I am turning these into zero round events, to reflect
                    //   the weirdness of the new encounter string.
                    string[string] saberReplace;
                    
                    // Figure out what I'm remapping the saber choice to
                    saberReplace['You will go find two friends'] = 'SABER FRIENDS';
                    saberReplace['You will drop your things'] = 'SABER YELLOW RAY';
                    saberReplace['I am not the adventurer'] = 'SABER BANISH';
                    
                    foreach str, finStr in saberReplace {
                        if (contains_text(currLine,str)){
                            // Change the line string to a proper combat format
                            currLine = "Round 0: "+myName+" casts "+finStr;

                            // Populate the saber map
                            saberUsed[count(saberUsed)] = new saber (currDay, currTurn, encounterTitle, finStr);
                        }
                    }
                }

                // Heist is choice 1320!
                if (contains_text(currLine,'Took choice 1320')){

                    // Change the line string & increment your heist counter
                    currLine = "["+currTurn.to_string()+"] HEIST: Stealing an item!";
                    famLog[$familiar[ Cat Burglar ]].actions += 1;

                }

                // Also, this -isn't- fake -- I'm transforming Doc Awk's office.
                if (contains_text(currLine, 'Visiting Dr. Awkward')){
                    currLine = "["+currTurn.to_string()+"] Dr. Awkward's Office";
                }
            }
        }

        // Now that we have remapped our lines, let's parse those lines!

         if (length(currLine) < 9){
             // No line should be < 8, but any line w/ <8 messes 
             //   up fam parsing, so bypassing them
             if (length(currLine) == 0 && inTurn){
                // Letting Mafia know not to capture between-turn info, for now
                inTurn = false;
                
                if (isFake(currLoc)){
                    // This is a little kludgy. But, if it's a synthetic turn (ie,
                    //   one that I manually generated) I want it to generate & submit
                    //   that action into the synthetic action log, which is to be
                    //   cleared every time it gets placed into the actual log. This
                    //   ensures that my freeturn capture works correctly on "pure" 
                    //   logged objects. 

                    // First, though, add pizza ingredients to pizzas!
                    if (currLoc == "CONSUME: eat 1 diabolic pizza"){
                        encounterTitle = pizzaIngredients;

                        // Also, populate the pizza map! Using Katarn's neat
                        //   commenting trick to comment out the newline and
                        //   ensure I can have line breaks in the assignment.

                        pizzaUsed[count(pizzaUsed)] = new pizza (currDay,      /*
                        */ currTurn, advGain, mus, mys, mox, pizzaIngredients, /*
                        */ effectsGained, itemsGained);     
                    }

                    fakeLog[1]  = currDay.to_string();
                    fakeLog[2]  = currTurn.to_string();
                    fakeLog[3]  = 'TRUE';
                    fakeLog[4]  = currLoc;
                    fakeLog[5]  = encounterTitle;
                    fakeLog[6]  = currFam.to_string();
                    fakeLog[7]  = itemsGained;
                    fakeLog[8]  = meat.to_string();
                    fakeLog[9]  = combatRound.to_string();
                    fakeLog[10] = mus.to_string();
                    fakeLog[11] = mys.to_string();
                    fakeLog[12] = mox.to_string();
                    fakeLog[13] = advGain.to_string();
                    fakeLog[14] = effectsGained;
                    fakeLog[15] = itemsUsed;
                    fakeLog[16] = skills;
                    fakeLog[17] = freeRun.to_string();
                    fakeLog[18] = banished.to_string();
                    fakeLog[19] = freekill.to_string();
                    fakeLog[20] = sniff.to_string();
                    fakeLog[21] = spit.to_string();
                    fakeLog[22] = copier.to_string();
                    fakeLog[23] = origMonster;

                    submitToLog(fakeLog, fLog);

                } else {
                    // Export prior turn information into what will eventually 
                    //   be the log; order is specific! eventLog is for non-fake
                    //   stuff, fakeLog is for fake turns I made up to ensure 
                    //   the log captures consumption info
                    eventLog[1]  = currDay.to_string();
                    eventLog[2]  = currTurn.to_string();
                    eventLog[3]  = freeTurn.to_string();
                    eventLog[4]  = currLoc;
                    eventLog[5]  = encounterTitle;
                    eventLog[6]  = currFam.to_string();
                    eventLog[7]  = itemsGained;
                    eventLog[8]  = meat.to_string();
                    eventLog[9]  = combatRound.to_string();
                    eventLog[10] = mus.to_string();
                    eventLog[11] = mys.to_string();
                    eventLog[12] = mox.to_string();
                    eventLog[13] = advGain.to_string();
                    eventLog[14] = effectsGained;
                    eventLog[15] = itemsUsed;
                    eventLog[16] = skills;
                    eventLog[17] = freeRun.to_string();
                    eventLog[18] = banished.to_string();
                    eventLog[19] = freekill.to_string();
                    eventLog[20] = sniff.to_string();
                    eventLog[21] = spit.to_string();
                    eventLog[22] = copier.to_string();
                    eventLog[23] = origMonster;
                }
             }
         }
         else if (substring(currLine,0,1) == "["){
            // This initializes an encounter; passes up turn/loc info, etc
            inTurn = true;

            // Catch to determine if the last turn was free. Have
            //   to also make sure it isn't using the info from 
            //   fake events, present in this exact line!
            if (currLine == "[0] FREEING THE DING DANG KING"){
                // Trying to fix the error where Goo runs show a 0 turn ending.
                print("Parsing a goo run, it looks like?", "blue");
            } else {
                if (currTurn == grabNumber(currLine) && !isFake(split_string(currLine,"] ")[1])){
                    freeTurn = true;
                } else {
                    currTurn = grabNumber(currLine);
                }
            }

            // Unlike... basically everything else, I am using
            //   the next turn to ascertain if the prior turn 
            //   was free before submitting it. This is a way
            //   to make *absolutely* sure the log's "free 
            //   turn" column is correct.
            eventLog[3]  = freeTurn.to_string();

            // Only submit if a turn has actually been captured. It
            //   should only equal "day" if we are still on the log
            //   log header. Also, make sure you aren't in a fake.
            if (eventLog[1] != "day" && !isFake(split_string(currLine,"] ")[1])){
                // Append the "fake turns" log.
                rLog.append(fLog);

                // Flush the fLog buffer, because we're submitting it.
                delete(fLog, 0, length(fLog));

                // Finally, submit the event to rLog.
                submitToLog(eventLog, rLog);

                // Now that we are submitting a turn, we can now 
                //   adjust for whether running with a bander or 
                //   boots as your active familiar was -actually- 
                //   a free run. 17 is the free run flag, 6 is the
                //   used familiar, 3 is the "freeTurn" t/f.
                if (eventLog[17].to_int() > 0 && isRunner(eventLog[6].to_familiar()) ){
                    if (!eventLog[3].to_boolean()){
                        // Only do anything if it -wasn't- a free 
                        //   turn. Otherwise we're all good. 
                        eventLog[17] = (eventLog[17].to_int() - 1).to_string();
                        famLog[eventLog[6].to_familiar()].actions -= 1;
                    }
                }

                // Hey! Since we're submitting stuff, let's take this
                //   golden opportunity to populate our famLog & our
                //   locLog. This doesn't add a turn for saber turns,
                //   because we reset those to rounds = 0.
                int roundInt = eventLog[9].to_int();

                // Populating the famLog
                if (roundInt > 0){
                    // Only capture when rounds > 0
                    famLog[eventLog[6].to_familiar()].turns += 1;
                }

                // Populating the locLog 
                if (roundInt == -1 && !freeTurn){
                    // Increment NC/advss when they aren't free
                    locLog[eventLog[4]].noncoms   +=1;
                    locLog[eventLog[4]].advs      +=1;

                } else if (roundInt > 0 && freeTurn){
                    // Increment freeTurns that aren't NCs 
                    locLog[eventLog[4]].freeTurns  +=1;

                } else if (!freeTurn){
                    // Increment combat advs 
                    locLog[eventLog[4]].advs      +=1;

                }
                
                // Update the rest of the data
                locLog[eventLog[4]].banishes   += eventLog[18].to_int();
                locLog[eventLog[4]].freekills  += eventLog[19].to_int();
                locLog[eventLog[4]].spits      += eventLog[21].to_int();
                locLog[eventLog[4]].copiers    += eventLog[22].to_int();
                locLog[eventLog[4]].runs       += eventLog[17].to_int();
            }
            

            // Reset state-based variables for a new turn
            combatRound = -1;
            mus = 0;
            mys = 0;
            mox = 0;
            meat = 0;
            advGain = 0;
            itemsUsed = "";
            skills = "";
            effectsGained = "";
            itemsGained = "";
            origMonster = "";
            encounterTitle = "N/A";
            freeTurn = false;
            banished = 0;
            freekill = 0;
            sniff = 0;
            spit = 0;
            copier = 0;
            freeRun = 0;

            newLoc = split_string(currLine,"] ")[1];
            
            // A few manual clean-ups here. Naturally, mafia logs the
            //   exact square in the tavern that you adventured in. I
            //   generally do not want those in a log, so I rename. 
            //   The same behavior occurs in the daily dungeon.

            string[string] substituteLocs;

            substituteLocs["The Daily Dungeon"] = "The Daily Dungeon";
            substituteLocs["The Typical Tavern"] = "The Tavern Cellar";
            substituteLocs["Combing"] = "Combing the Beach";
            substituteLocs["Tower Level"] = "The Naughty Sorceress' Tower";
            substituteLocs["The Lower Chambers"] = "The Lower Chambers";
            substituteLocs["The Hedge Maze"] = "The Hedge Maze";
            substituteLocs["Eldritch Attunement"] = currLoc; // replace attunement w/ prior loc
            substituteLocs["null"] = currLoc; // replace nulls w/ prior loc

            foreach loc, replacement in substituteLocs{
                if (contains_text(newLoc, loc)){
                    newLoc = replacement;
                }
            }

            // Finally, set the cleaned location.
            currLoc = newLoc;


         }
         else if (currLine == "Encounter: Using the Force"){
            // Do *not* revise the encounter title with this.
         }
         else if (inTurn && substring(currLine,0,5) == "Encou") {
            // Generate encounter title; is either monster name, or NC title
            //   Including a count here to account for empty encounter titles
            if (count(split_string(currLine,"ounter: ")) > 1){
                encounterTitle = split_string(currLine,"ounter: ")[1];
            } else {
                encounterTitle = "N/A";
            }
         }
         else if (substring(currLine,0,5) == "Round"){
            // All "round" statements are filled with useful crap!
            combatRound = grabNumber(currLine);

            // Some "round" statements are for monsters; others are for you! I'm
            //   currently ignoring damage dealt, a main usage of monster stmts.
            //   Before doing this, you have to make sure the line is long enough
            //   to possibly contain the player's name, tho. (Thanks, 3BH, for 
            //   helping track this weird error down.)
			if (count(split_string(currLine,": ")) == 1){
                continue;
            }
            if (length(split_string(currLine,": ")[1]) > length(myName)){
                if (substring(split_string(currLine,": ")[1],0,length(myName)) == myName){
                    // This detects if it's a statement about you! And this cuts out
                    //   the specific statement after "round" & your name
                    roundStmt = split_string(currLine,myName+" ")[1];

                    // Now to split out useful pieces; these can be:
                    //   - casts [SKILL]!
                    //   - uses the [ITEM]!
                    //   - uses the [ITEM] and uses the [ITEM]!

                    // Firstly, remove the !, so the parser works properly. Replace
                    //   string generates a buffer, so have to make it a string again.
                    roundStmt = replace_string(roundStmt, "!", "").to_string();

                    // For item logic, want to remove the 2nd "and".
                    roundStmt = replace_string(roundStmt, " and ", "").to_string();

                    // Here, we're just feeding it into our banish/freekill/sniff 
                    //   functions. I included the "length>0" catch to ignore the
                    //   first element of the iteration. You need to have the 
                    //   foreach for items due to funkslinging; technically you
                    //   don't NEED it for skills, but I want syntax to align.

                    if (substring(roundStmt,0,4) == "cast"){
                        foreach idx, ss in split_string(roundStmt,"casts "){
                            if (length(ss) > 0){
                                banished += isSpecial(ss,"skill",banisherList);
                                freekill += isSpecial(ss,"skill",freeKillList);
                                sniff    += isSpecial(ss,"skill",sniffList);
                                copier   += isSpecial(ss,"skill",copyList);
                                spit     += ("%FN, SPIT ON THEM" == ss).to_int();
                                freeRun  += isSpecial(ss,"skill",runList);
                                skills   = skills+" | "+ss;

                                // Increment spits for melodramedary
                                if (ss == "%FN, SPIT ON THEM"){
                                    famLog[$familiar[ Melodramedary ]].actions += 1;
                                }

                                // Increment lectures for prof
                                if (contains_text(ss, "LECTURE ON")){
                                    famLog[$familiar[ Pocket Professor ]].actions += 1;
                                }

                                // Increment runs for boots & banders. Note that 
                                //   we also have to adjust to ensure they were 
                                //   actually -free- runs, which we do up top.
                                if (ss == "RETURN"){
                                    if (isRunner(currFam)){
                                        famLog[currFam].actions += 1;
                                        // Also, increment the run counter.
                                        freeRun  += 1;
                                    }
                                }
                            }
                        }
                    } else if (substring(roundStmt,0,4) == "uses"){
                        foreach idx, ss in split_string(roundStmt,"uses the "){
                            if (length(ss) > 0){
                                banished += isSpecial(ss,"item",banisherList);
                                freekill += isSpecial(ss,"item",freeKillList);
                                sniff    += isSpecial(ss,"item",sniffList);
                                freeRun  += isSpecial(ss,"item",runList);
                                itemsUsed = itemsUsed+"|"+ss;
                            }
                        }
                    }
                } 
            }

            if (contains_text(currLine, "your opponent becomes ")){
                // Handling macrometeor-type skills here
                origMonster = origMonster+" | "+encounterTitle;
                encounterTitle = split_string(currLine,"your opponent becomes ")[1];
            }
         }
         else if (substring(currLine,0,5) == "After"){
             // Capturing after-battle stat changes. 
             mus += statChange(currLine,"mus");
             mys += statChange(currLine,"mys");
             mox += statChange(currLine,"mox");
         }
         else if (substring(currLine,0,5) == "%%%%%"){
             // This captures which day of the run it is, to pass that up to my static vars
             currDay = split_string(currLine,"DAY #")[1].to_int();
         }
         else if (substring(currLine,0,9) == "familiar "){
            // Convert "familiar [FAMNAME] (WEIGHT)" lines into $fam var
            if (index_of(currLine," (") == -1){
                // If it DOESN'T have the ( for weight, it's a "familiar none" cmd
                currFam = $familiar[ none ];
            } else {
                currFam = substring(currLine,8,index_of(currLine," (")).to_familiar();
            }
            // print("Switched to "+currFam,"purple"); // Print to make sure it's working. 
         }
         else if (substring(currLine,0,5) == "pull:"){
             // Convert "pull: # [ITEMPULLED]" into additions to pull list
            int numPull = grabNumber(currLine);
            string pullName = substring(currLine,5+length(numPull.to_string())+1);
            for n from numPull downto 1{
                numPulls += 1;
                runPulls[count(runPulls)] = new pulls (currDay, currTurn, numPulls, pullName);
            }
         }
         else if (inTurn && substring(currLine,0,6) == "You ac"){
             // This captures if you have gained an item or an effect
            if (contains_text(currLine,"acquire an item: ")){
                itemsGained = itemsGained+" | "+split_string(currLine,"acquire an item: ")[1];
                
                // Track when you get human musks for snapper tracking
                if (contains_text(currLine,"human musk")){
                    famLog[$familiar[ Red-Nosed Snapper ]].actions += 1;
                }

            } else if (contains_text(currLine,"acquire an effect: ")){
                effectsGained = effectsGained+" | "+split_string(currLine,"acquire an effect: ")[1];
            }
                
         }
         else if (inTurn && contains_text(currLine,"You gain ")){
             // This captures if you have gained meat within a turn
            if (contains_text(currLine, "Meat")){
                meat = meat + grabNumber(currLine);
            }
            if (contains_text(currLine, "Adventures")){
                advGain = advGain + grabNumber(currLine);
            }
            
         }
         else if (substring(currLine,0,5) == "pizza"){
             // Capturing pizza ingredients! The format mafia appears to use is:
             //   pizza [ingred1], [ingred2], [ingred3], [ingred4]
             // So I am converting this into an ingredients string.

             pizzaIngredients = ": " + strip(substring(currLine,5));
             string[int] ingredList = split_string(strip(substring(currLine,5)),",");

             // Also, add a pre-pend string showing the first 4 letters.
             for i from 3 downto 0 {
                string firstLetter = substring(strip(ingredList[i]),0,1).to_string();
                pizzaIngredients =  to_upper_case(firstLetter) + pizzaIngredients;
             }
         }
         else {
             //print(currLine,"red");
         }
    }

    // Populate the famLog's action types for familiars with tracked actions.
    static string[familiar] famActions = {
        $familiar[ Melodramedary ]          : "spits",
        $familiar[ Pocket Professor ]       : "lectures",
        $familiar[ Pair of Stomping Boots ] : "runs",
        $familiar[ Red-Nosed Snapper ]      : "human musks",
        $familiar[ Cat Burglar ]            : "heists",
    };

    // Populate action types for tracked familiars
    foreach fam, action in famActions {
        famLog[fam].actionType = action;
    }

    // Now that you've finished populating the log, time to generate
    //   a resource report for the end user. First, locations.

    // Append a header, first.
    runReport.append("LOCATION\tADVS\tFREETURNS\tNCs\tBANISHES\tFREEKILLS\tSPITS\tCOPIERS\tRUNS\n");
    
    foreach loc, thisLoc in locLog {
        // I am using the "submitToLog" function so that it's easy to
        //   convert all output into CSV/TSV. Might make that a user
        //   defined option at some point. 
        string[int] submitString;

        submitString[1] = loc.to_string();
        submitString[2] = thisLoc.advs;
        submitString[3] = thisLoc.freeTurns;
        submitString[4] = thisLoc.noncoms;
        submitString[5] = thisLoc.banishes;
        submitString[6] = thisLoc.freekills;
        submitString[7] = thisLoc.spits;
        submitString[8] = thisLoc.copiers;
        submitString[9] = thisLoc.runs;

        int locSum = thisLoc.advs + thisLoc.freeTurns + thisLoc.noncoms + thisLoc.banishes + thisLoc.freekills + thisLoc.spits + thisLoc.copiers + thisLoc.runs;

        // If the location data shows that nothing important happened,
        //   skip it in the location log.
        if (locSum > 0){
            submitToLog(submitString,runReport);
        }

    }
    
    // Adding a break between each resource saved
    runReport.append("\n====================\n");

    // Append a header, first.
    runReport.append("FAMILIAR\tTURNS\tACTIONS\tACTIONTYPE\n");
    
    foreach fam, thisFam in famLog {
        // I am using the "submitToLog" function so that it's easy to
        //   convert all output into CSV/TSV. Might make that a user
        //   defined option at some point. 
        string[int] submitString;

        submitString[1] = fam.to_string();
        submitString[2] = thisFam.turns;
        submitString[3] = thisFam.actions;
        submitString[4] = thisFam.actionType;
        
        // Only send the fam line if the fam was actually used.
        if (thisFam.turns > 0) {
            submitToLog(submitString,runReport);
        }
    }
    
    // Adding a break between each resource saved
    runReport.append("\n====================\n");

    // Ensure a pill was used before doing this.
    if (count(pillsUsed)>1){
        // Append a header, too.
        runReport.append("PILLTYPE\tDAY\tTURN\n");

        foreach i,currPill in pillsUsed {
            // I am using the "submitToLog" function so that it's easy to
            //   convert all output into CSV/TSV. Might make that a user
            //   defined option at some point. 
            string[int] submitString;

            submitString[1] = currPill.pillType;
            submitString[2] = currPill.day;
            submitString[3] = currPill.turn;

            submitToLog(submitString,runReport);
        }
        
        // Adding a break between each resource saved
        runReport.append("\n====================\n");
    }

    // Now, pizzas!
    if (count(pizzaUsed)>1){
        // Append a header, too.
        runReport.append("INGREDIENTS\tDAY\tTURN\tADVS\tEFFECT\tITEMS\tMUS\tMYS\tMOX\n");
            
        foreach i, currZa in pizzaUsed {
            // I am using the "submitToLog" function so that it's easy to
            //   convert all output into CSV/TSV. Might make that a user
            //   defined option at some point. 
            string[int] submitString;

            submitString[1] = currZa.ingredients;
            submitString[2] = currZa.day;
            submitString[3] = currZa.turn;
            submitString[4] = currZa.advs;
            submitString[5] = currZa.effectGiven;
            submitString[6] = currZa.itemsDropped;
            submitString[7] = currZa.mus;
            submitString[8] = currZa.mys;
            submitString[9] = currZa.mox;

            submitToLog(submitString,runReport);
        }
        
        // Adding a break between each resource saved
        runReport.append("\n====================\n");
    }
    
    // Now, sabers!
    if (count(saberUsed)>1){
        // Append a header, too.
        runReport.append("SABERTYPE\tDAY\tTURN\tSABERMONSTER\n");
        
        foreach i, currSaber in saberUsed {
            // I am using the "submitToLog" function so that it's easy to
            //   convert all output into CSV/TSV. Might make that a user
            //   defined option at some point. 
            string[int] submitString;

            submitString[1] = currSaber.saberType;
            submitString[2] = currSaber.day;
            submitString[3] = currSaber.turn;
            submitString[4] = currSaber.saberMonster;

            submitToLog(submitString,runReport);
        }
        
        // Adding a break between each resource saved
        runReport.append("\n====================\n");
    }

    // Finally, pulls.
    if (count(runPulls)>1){
        // Append a header, too.
        runReport.append("PULL\tDAY\tTURN\tNUMBER\n");
        
        foreach i, currPull in runPulls {
            // I am using the "submitToLog" function so that it's easy to
            //   convert all output into CSV/TSV. Might make that a user
            //   defined option at some point. 
            string[int] submitString;

            submitString[1] = currPull.pull;
            submitString[2] = currPull.day;
            submitString[3] = currPull.turn;
            submitString[4] = currPull.num;

            submitToLog(submitString,runReport);
        }
        
        // Adding a break between each resource saved
        runReport.append("\n====================\n");
    }

    buffer_to_file(rlog,fName+currTurn+"turns.tsv");
    if (get_property("scotchLogResourceTracker")=="save"){
        buffer_to_file(runReport,fName+currTurn+"turns_runReport.tsv");
    }

}

void generateRawLog(string runEndDate, int numDays){

    // =========================================================
    // -- NOTE: This function deviates minimally from RunLogSum
    // =========================================================

    // Use the janky "days since" function to figure out # of days
    int dSince = daysFromToday(runEndDate);

    if (dSince == 0 && runEndDate != now_to_string("yyyyMMdd")){
        abort("ERROR: You are trying to parse zero days of logs.");
    }

    // Initialize logs of days & total runLog. Using a buffer 
    //   because it appears to play nicer with regex?
    string dayLog = "";
    buffer rawLog;
    append(rawLog,"[0] Start \n");
    int dayNum = 0;
    int upperBound = dSince+numDays;

    // This appears to store in a strange order; on the 7th day, 
    //   D1 is 6, D7 is 0. It works, tho, and that's what matters!
    string[int] slogs = session_logs(upperBound);

    // Because session_logs() stores in reverse, iterate downwards
    for i from upperBound downto dSince{

        // Grab one day's log, append to rawLog
        if (i-1 > -1){ dayLog = slogs[i-1];}
        else { dayLog = "???";}

        // I used to use this as an error. Instead, just printing a warning.
        if (dayLog == ""){
            print("ERROR: Mafia generated an empty runlog for one of your sessions. Skipping that day. (It occurred @ index ="+i+")");
        } else {
            dayNum += 1;
            append(rawLog,"%%%%%%%%% START OF DAY #"+dayNum+"\n");
            append(rawLog, dayLog);
        }

    }

    // Use "index_of()" to locate ascension start
    int iSTART = -1;
	
    // Use runStartList to reference starting strings 
    foreach x, typ in runStartList {
	    int startRun = index_of(rawLog, x);
	    if (startRun > 0){
	        iSTART = index_of(rawLog, x);
	    }
    }
	
    // Error catching for users not including run starts.
    if(iSTART == -1){abort("ERROR: This didn't include the beginning of a new run. Try again?");}

    // Use a replace function to remove all front-matter
    replace(rawLog, 0, iSTART, "%%%%%%%%% START OF DAY #"+1+"\n");

    // Use "index_of()" to locate ascension end
    int iPRISM = -1;

    // Use 3BH's kingFreedList to reference end string for CS
    foreach x, typ in kingFreedList {
        int endRun = index_of(rawLog, x);
        if (endRun > 0){
            iPRISM = index_of(rawLog, x);
        }
    }

    // Error catching for users not including run ends.
    if(iPRISM == -1){ 
        // Add a catch for goo, where there is no explicit run-end in the log syntax. 
        //   Helpfully, since this is astral, it should (?) help catch future paths 
        //   where you don't free a king. We'll see!
        int endRun = index_of(rawLog, "Welcome to Valhalla!");
        if (endRun > 0){
            iPRISM = endRun;
        } else {
            abort("ERROR: This didn't include the end of a run. Try again?");
        }
    }

    // Use a replace function to remove all end-matter.
    replace(rawLog, iPRISM, length(rawLog), "[0] FREEING THE DING DANG KING");

    string newLog = rawLog.to_string();

    // Using [GROAN] regex to find the actual daycount.
    matcher dayMatcher = create_matcher("%%% START OF DAY #[\\d+]*", newLog);

    int finalDay;

    while (dayMatcher.find()){
        finalDay = grabNumber(dayMatcher.group(group_count(dayMatcher)));
    } 

    string fileName = replace_string(myName," ","_")+"_"+runEndDate+"_"+finalDay+"day";

    if (get_property("scotchLogMafioso")=="save"){
        buffer_to_file(rawLog,fileName+"_mafioso.txt");
    }

    // At this point, the raw log is ready to be parsed.
    parseLog(newLog,fileName);
}

void setLoggerDefaults(){
    // Helper function that sets mafia preferences to defaults if
    //   they are not yet set. 

    // Sets whether or not to save the mafioso concat file
    if (get_property("scotchLogMafioso")==""){
        set_property("scotchLogMafioso","nosave");
    }
    // Sets whether or not to save the resource log file
    if (get_property("scotchLogResourceTracker")==""){
        set_property("scotchLogResourceTracker","save");
    }
}

void executeCommand(string cmd){
    // Using Ezan's code structure here; will help me build different 
    //   options going forward. Start by setting defaults if they
    //   aren't already set.

    setLoggerDefaults();

	if (cmd == "help" || cmd == "" || cmd.replace_string(" ", "").to_string() == ""){
        // If they're asking for help, output the docstring.
        outputHelp();

    } else if (cmd == "links"){
        // If they're asking for links, output that. This is 
        //   extremely obvious. Why am I commenting this?
        outputLinks();

    } else if (substring(cmd,0,5) == "parse"){
        // If the user is sending a "parse" command, look for
        //   the date string & the # of days in the command.
        //   Start by setting date/days defaults; default to 
        //   CKB's parser behavior, ie most recent log

        string ascDate = now_to_string("yyyyMMdd");
        int ascDays = my_daycount();

        foreach idx,str in split_string(cmd," "){
            // Some basic "is the cmd what we're expecting?" logic
            if (idx==1 && length(str) == 8 && str.to_int() > 20010911){ascDate = str;}
            if (idx==2 && str.to_int() > 0){ascDays = str.to_int();}
        }

        print_html("<strong>========= SCOTCH-LOG-PARSER v" + __scotchLog_version+" =========</strong>");
        print("Examining logs starting at "+ascDate+" and going back "+ascDays+" days.");
        generateRawLog(ascDate, ascDays);
    }
    else if (substring(cmd,0,5) == "mafio"){
        // If the user is sending a "mafioso" command, set the
        //   property to what they've submitted, if it's "save" 
        //   or "nosave", the only two valid values

        string newPropVal = "n/a";

        foreach idx,str in split_string(cmd," "){
            // Some basic "is the cmd what we're expecting?" logic
            if (idx==1 && str=="save"){   newPropVal = "save";}
            if (idx==1 && str=="nosave"){ newPropVal = "nosave";}
        }

        if (newPropVal == "n/a"){
            print("WARNING: Not a valid command! Try using \"mafioso save\" or \"mafioso nosave\".","red");
        } else {
            print("Setting the Mafioso setting for ScotchLogParser to '"+newPropVal+"'.","purple");
            set_property("scotchLogMafioso",newPropVal);
        }

    }
    else if (substring(cmd,0,5) == "resou"){
        // If the user is sending a "resource" command, set the
        //   property to what they've submitted, if it's "save" 
        //   or "nosave", the only two valid values

        string newPropVal = "n/a";

        foreach idx,str in split_string(cmd," "){
            // Some basic "is the cmd what we're expecting?" logic
            if (idx==1 && str=="save"){   newPropVal = "save";}
            if (idx==1 && str=="nosave"){ newPropVal = "nosave";}
        }

        if (newPropVal == "n/a"){
            print("WARNING: Not a valid command! Try using \"resource save\" or \"resource nosave\".","red");
        } else {
            print("Setting the Resource Log setting for ScotchLogParser to '"+newPropVal+"'.","purple");
            set_property("scotchLogResourceTracker",newPropVal);
        }

    }
    else if (substring(cmd,0,5) == "daybt"){
        // Substring to test the daybt function
        print(daysFromToday(split_string(cmd," ")[1]));
    }
    else {
        print("Invalid command. Try submitting 'scotchlog help' for more info.", "red");
    }
    
}

void main(string command){

    executeCommand(command);

}
