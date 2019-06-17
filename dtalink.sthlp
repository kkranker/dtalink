{smcl}
{* $Id: dtalink.sthlp,v ef60d24f466f 2019/02/13 03:41:09 kkranker $}{...}
{* Copyright (C) Mathematica Policy Research, Inc. This code cannot be copied, distributed or used without the express written permission of Mathematica Policy Research, Inc.}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "append" "help append"}{...}
{vieweralsosee "reshape" "help reshape"}{...}
{vieweralsosee "using" "help using"}{...}
{viewerjumpto "Syntax" "dtalink##syntax"}{...}
{viewerjumpto "Description" "dtalink##description"}{...}
{viewerjumpto "Options" "dtalink##options"}{...}
{viewerjumpto "Remarks" "dtalink##remarks"}{...}
{viewerjumpto "Author" "dtalink##author"}{...}
{viewerjumpto "Examples" "dtalink##examples"}{...}
{viewerjumpto "Stored results" "dtalink##results"}{...}
{viewerjumpto "References" "dtalink##references"}{...}
{title:Title}

{phang}
{bf:dtalink} {hline 2} Probabilistic data linking or deduplication for large data files


{marker syntax}{...}
{title:Syntax}

{phang2}
{cmdab:. dtalink}
{it:dspecs}
{ifin} [{help using} {it:filename}]
[{cmd:,} {it:options}]{p_end}

{phang3}where {it:dspecs} = {it:dspec} [ {it:dspec} [ {it:dspec} [...]]]{p_end}

{phang3}and {it:dspec} = {varname} {it:#1 #2} [{it:#3}]{p_end}

{phang3}and {varname} is a matching variable,
{it:#1} is the (positive) weight applied for a match,
{it:#2} is the weight applied for a nonmatch (negative), and
{it:#3} is the caliper for distance matching (positive).
If a caliper is not specified, exact matching is used.{p_end}


{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main options}
{synopt:{opt s:ource(varname)}}identifies source file (for data linking){p_end}
{synopt:{opt cut:off(#)}}determines the minimum score required to keep matched pairs; the default is cutoff(0){p_end}
{synopt:{opt id(varname)}}identifies unique cases to be matched; use if there is more than one record (row) per case{p_end}
{synopt:{opt b:lock(blockvars)}}declares blocking variables{p_end}
{synopt:{opt calc:weights}}recommends weights for next run{p_end}
{synopt:{opt best:match}}enables 1:1 linking{p_end}
{synopt:{opt srcbest:match(0|1)}}enables 1:M or M:1 linking{p_end}
{synopt:{opt combine:sets}}creates groups that may contain more than three cases{p_end}
{synopt:{opt alls:cores}}keeps all scores for a pair, not just the maximum.{p_end}
{synoptline}
{syntab:Options to format output file}
{synopt:{opt wi:de}}outputs a crosswalk file in a "wide" {help dtalink##formatting:format} (rather than "long"){p_end}
{synopt:{opt nome:rge}}prevents the crosswalk file (in "long" format) from being merged back onto original data{p_end}
{synopt:{opt miss:ing}}treats missing strings ("") as their own group in both non-numeric match variables and blocking variables {p_end}
{synopt:{opt fill:unmatched}}fills the _matchID variable with a unique identifier for unmatched observations; the default is _matchID = . for unmatched observations{p_end}
{synoptline}
{syntab:{help using} options}
{synopt:{opt nol:abel}}do not copy value-label definitions from data set(s) on disk{p_end}
{synopt:{opt non:otes}}do not copy notes from data set(s) on disk{p_end}
{synoptline}
{syntab:Display options}
{synopt:{opt nowei:ghttable}}suppresses the table with the matching weights{p_end}
{synopt:{opt desc:ribe}}show a list of variables in the new data set{p_end}
{synopt:{opt examples(#)}}prints approximately # rows to the log file as examples; the default is examples(0) (no examples){p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}Data linking is applied if the {it:source()} option or {help using} are specified; otherwise, data deduplication is applied.{p_end}
{p 4 6 2}{it:blockvars} is a list of one or more blocking variables.
       If multiple variables are entered, each unique combination of the variables is considered a block.
       To specify multiple sets of blocks, separate blocking variables with "|", such as block(bvar1 | bvar2 bvar3 | bvar4).
       (Variable name abbreviations are not allowed in {it:blockvars}.) {p_end}
{p 4 6 2}After the {help using}, one specifies a valid {it:{help filename}}.
         Specify the filename in quotes if it contains blanks or other special characters.
         If a {it: filename} is specified without an extension, .dta is assumed.

{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}Stata users often need to link records from two or more data files or find duplicates within data files.
Probabilistic linking methods are often used when the file(s) do not have reliable or unique identifiers,
causing deterministic linking methods (such as Stata's {help merge}, {help joinby}, or {help duplicates} commands) to fail.
For example, one might need to link files that only include
inconsistently spelled names, dates of birth with typos or missing data, and addresses that change over time.
Probabilistic linking methods score each potential pair of records using the matching variables and weights
(Newcombe et al. 1959; Fellegi and Sunter 1969).
Pairs with higher overall scores indicate a better match than pairs with lower scores.{p_end}

{pstd}{cmd:dtalink} implements probabilistic linking methods (a.k.a. probabilistic matching) for two cases:{p_end}
{phang2}(1) linking records in two data files{p_end}
{phang2}(2) deduplicating records in one data file{p_end}

{pstd}There are two ways to implement data linking (case 1): {p_end}
{phang2}(a) the user stacks the two data sets before running {cmd:dtalink}
and provides a dummy to indicate the file in the {opt source(varname)} option, or {p_end}
{phang2}(b) the user provides the name of the second file with [{help using} {it:filename}],
in which case the master data set is assigned {opt source}=0 and the {it:using} data set is assigned {opt source}=1{p_end}
{pstd}If neither of these are specified, data deduplication (case 2) is implemented. {p_end}

{pstd}The user specifies matching variables and matching weights.
For each matching variable, users can use one of two methods to compare two records for a potential match:{p_end}
{phang2}(a) Exact matching awards positive weights
if {cmd:(}{it:X for observation 1}{cmd:)} equals {cmd:(}{it:X for observation 2}{cmd:)},
awards negative weights if the observations are not equal,
and awards no weights if one of the observations is missing.{p_end}
{phang2}(b) Caliper matching awards positive weights if
{cmd:|(}{it:X for observation 1}{cmd:)-(}{it:X for observation 2}{cmd:)|} is less than or equal to the {it:caliper} for {it:X},
awards negative weights if the difference is greater than the {it:caliper},
and awards no weights if {it:X} is missing for either of the observations.{p_end}

{pstd}{cmd:dtalink} offers streamlined probabilistic linking methods.
The computationally heavy parts of the program are implemented in a Mata class with parallelized Mata code,
making it practical to implement the methods with large, administrative data files
(files with many rows or matching variables). It is a generic function which works with any data file.
Flexible scoring and many-to-many matching techniques are also options.{p_end}


{marker options} {...}
{title:Options}

{dlgtab:Main}

{phang}{opt source(varname)} identifies the source file for data linking.
That is, the variable distinguishes between cases in files A and B.
{it:varname} must be a dummy (equal to 0 or 1).
This option is not allowed when a {help using} filename is provided.
Specifying the {it:source()} option (or a {it: using} filename) implies data linking;
data deduplication is assumed if neither are provided. {p_end}

{phang}{opt cutoff(#)} determines the minimum score required to keep a potential a match.
Matched pairs with scores below the specified amount are dropped (not returned to the user).
The default is cutoff(0).{p_end}

{phang}{opt id(varname)} identifies unique units if there is more than one record (row) per unit-to-be-matched.
(e.g., more than one record [row] per person [unit]). Cases are scored using the two best-matching records.
The default is to treat each row as a unique unit, by creating an id variable with this command: generate _id = _n{p_end}

{phang}{opt block(blockvars)} declares blocking variables.
Blocking reduces the computational burden of probabilistic matching.
Instead of comparing each observation in a file to every other observation, blocking skips potential match pairs that
do not share at least one blocking variable in common.
Blocking variables can be matching variables, and vice versa.
For example, blocks could be formed by {it:lastname};
to be considered a match, two observations would need to match on {it:lastname} to be scored as a match.
(Matches that do not match on {it:lastname} would not be compared at all.){p_end}

{pmore}{it:blockvars} is a list of one or more blocking variables.
If multiple variables are entered, each unique combinations of the variables is considered a block.
To specify multiple sets of blocks, separate blocking variables with "|", such as block(bvar1 | bvar2 bvar3 | bvar4).
(Variable name abbreviations are not allowed in {it:blockvars}.) {p_end}

{pmore}For large data sets, it is often advisable to specify several blocking variables.
Attempting to match with no blocks could lead to undesirable run times.
Specifying only one or two blocking variables will only find exact matches on those variables.
The blocking variables will usually also be included in the list of matching variables.{p_end}

{phang}{opt calcweights} recommends weights for a following run.
When conducting the linking, this option tracks the percentage of times a variable matches,
separately for potential match pairs above and below the cutoff.
After the linking, it uses these percentages to compute recommended weights (for a re-run, perhaps){p_end}

{pmore}Weights are calculated as follows:{p_end}
{phang3}r(new_dst_poswgt) = log_2(p1/p2){p_end}
{phang3}r(new_dst_negwgt) = log_2((1-p1)/(1-p2)){p_end}
{phang3}where p1 is the percentage of times the variable matched among matches and
p2 is the percentage of times the variable matched among nonmatches (using the current set of weights).{p_end}

{pmore}This option is more computationally intensive than the default (not performing these calculations);
specifying it could more than double runtimes.{p_end}

{phang}{opt bestmatch} enables 1:1 linking to avoid cases where an {cmd:id} is assigned to multiple _matchIDs.
After running this subroutine, each {cmd:id} will be assigned to no more than one _matchID.
The algorithm keeps the _matchID with the highest score, as long as neither {cmd:id} in _matchID is assigned to a different _matchID with a higher score.
That is, second-best matches are dropped for a given {cmd:id}.
(Ties are broken in descending order by _score, then ascending order by the {cmd:id}.)
For example, the {opt bestmatch} option might be used when the two data sets contain data on uniquely identified individuals
and one is trying to match each person to only one other person.{p_end}

{pmore}In the following example, the third matched pair is dropped by  {opt bestmatch}
       because record 1 was "already" matched to observation 10 with a higher score, and
       the fifth matched pair is dropped
       because record 13 was "already" matched to record 3 with a higher score.{p_end}

{p 16 16 2 0}{bind:         default                   bestmatch       }{break}
             {bind: +---------------------+   +---------------------+ }{break}
             {bind: |  _id0   _id1 _score |   |  _id0   _id1 _score | }{break}
             {bind: +---------------------+   +---------------------+ }{break}
             {bind: |     1     10     15 |   |     1     10     15 | }{break}
             {bind: |     2     12     13 |   |     2     12     13 | }{break}
             {bind: |     1     11      9 |   |                     | }{break}
             {bind: |     3     13      8 |   |     3     13      8 | }{break}
             {bind: |     4     13      7 |   |                     | }{break}
             {bind: +---------------------+   +---------------------+ }{p_end}

{phang}{opt srcbestmatch(0|1)} enables 1:M or M:1 linking to prevent an {cmd:id} in one of the files
from being assigned to multiple _matchIDs.
Users indicate a file: source=0 or source=1.
After running this subroutine, each {cmd:id} in the file indicated (0 or 1) will be assigned to no more than one {cmd:id} in the other file.
However each {cmd:id} in the other file could be assigned multiple _matchIDs.
Specifically, the algorithm keeps the _matchID with the highest score for each {cmd:id} in the file indicated.
Second-best matches are dropped for {it:ids} in the specified file.
(Ties are are broken in descending order by _score, then ascending order by the {it:ids} in the non-specified file.)
The {opt scrbestmatch(0)} option might be used, for example, when file=0 contains data on mothers and file=1 contains data on children,
and mothers could have more than one child.{p_end}

{pmore}In the following example, the third matched pair is dropped by  {opt scrbestmatch(0)}
       because record 1 was "already" matched to observation 10 with a higher score.
       The fifth matched pair is dropped by {opt scrbestmatch(1)}
       because record 13 was "already" matched to record 3 with a higher score.{p_end}

{p 16 16 2 0}{bind:       default                 srcbestmatch(0)           srcbestmatch(1)    }{break}
             {bind:+---------------------+   +---------------------+   +---------------------+ }{break}
             {bind:|  _id0   _id1 _score |   |  _id0   _id1 _score |   |  _id0   _id1 _score | }{break}
             {bind:+---------------------+   +---------------------+   +---------------------+ }{break}
             {bind:|     1     10     15 |   |     1     10     15 |   |     1     10     15 | }{break}
             {bind:|     2     12     13 |   |     2     12     13 |   |     2     12     13 | }{break}
             {bind:|     1     11      9 |   |                     |   |     1     11      9 | }{break}
             {bind:|     3     13      8 |   |     3     13      8 |   |     3     13      8 | }{break}
             {bind:|     4     13      7 |   |     4     13      7 |   |                     | }{break}
             {bind:+---------------------+   +---------------------+   +---------------------+ }{p_end}

{phang}{opt combinesets} is a subroutine to deal with case where an {cmd:id} is assigned to multiple _matchIDs.
With this option, _matchID will be updated to include all {it:ids} that met the {it:cutoff}.
One would often specify this option when deduplicating a file
(such as when one person appears three or more times in the data with different identification numbers).{p_end}

{pmore}In the following example,
       record 11 is combined into a single matched set with
       records 1 and 10 (since record 11 was matched to record 1)
       and records 3 and 4 were combined into a single matched set with
       records 2 and 12 (since they were both matched to record 12), {p_end}

{p 16 16 2 0}{bind:             default                       combinesets          }{break}
             {bind: +----------------------------+  +-----------------------------+ }{break}
             {bind: | _id0 _id1 _score  _matchID |  |  _id0  _id1 _score  _matchID| }{break}
             {bind: +----------------------------+  +-----------------------------+ }{break}
             {bind: |    1   10     15         1 |  |     1    10     15       1  | }{break}
             {bind: |    2   12     13         2 |  |     2    12     13       2  | }{break}
             {bind: |    1   11      9         3 |  |     1    11      9       {err:1}  | }{break}
             {bind: |    3   12      8         4 |  |     3    12      8       {err:2}  | }{break}
             {bind: |    4   12      7         5 |  |     4    12      7       {err:2}  | }{break}
             {bind: +----------------------------+  +-----------------------------+ }{p_end}

{phang}{opt allscores} keeps all scores for a pair, not just the maximum score.
By default, the program only keeps the max score for a matched pair;
but if {opt allscores} is used the program keeps all scores for a pair.
(This only has an effect on the results if id() is not unique.
That is, there are multiple rows per unit to be matched.){p_end}

{pmore}In the following example, the {opt allscores} option would keep the second row,
        which shows 1 and 10 being linked with a second score (13 in addition to 15).{p_end}

{p 16 16 2 0}{bind:        default              allscores       }{break}
             {bind: +------------------+  +-------------------+ }{break}
             {bind: | _id0 _id1 _score |  |  _id0  _id _score | }{break}
             {bind: +------------------+  +-------------------+ }{break}
             {bind: |    1   10     15 |  |     1   10     15 | }{break}
             {bind: |                  |  |     1   10     13 | }{break}
             {bind: +------------------+  +-------------------+ }{p_end}


{marker formatting}{...}
{dlgtab:Output file formatting}

{pstd}Matched pairs can be returned in a crosswalk using a {result:wide} format
or a {result:long} format (see {help reshape}).
In either format, a pair is defined by two cases (that is, two {result:_id}s),
a score ({result:_score}), and a unique identification number ({result:_matchID}).
In the {result:long} format, an additional variable ({result:_source}) is necessary to identify
the source file when linking two data files. (See below for an example.){p_end}

{p 16 16 2 0}{bind:          {result:Wide} format                       {result:Long} format          }{break}
             {bind:+----------------------------+  +------------------------------+}{break}
             {bind:|  _id0 _id1 _score _matchID |  | _matchID _source  _id _score |}{break}
             {bind:+----------------------------+  +------------------------------+}{break}
             {bind:|     1   10     15        1 |  |        1      0     1     15 |}{break}
             {bind:|     2   12     13        2 |  |        1      1    10     15 |}{break}
             {bind:|     1   11      9        3 |  +------------------------------+}{break}
             {bind:|     3   13      8        4 |  |        2      0     2     13 |}{break}
             {bind:+----------------------------+  |        2      1    12     13 |}{break}
             {bind:                                +------------------------------+}{break}
             {bind:                                |        3      0     1      9 |}{break}
             {bind:                                |        3      1    11      9 |}{break}
             {bind:                                +------------------------------+}{break}
             {bind:                                |        4      0     3      8 |}{break}
             {bind:                                |        4      1    13      8 |}{break}
             {bind:                                +------------------------------+}{p_end}

{pstd}By default, (1) results are returned in a {result:long} format,
                  (2) the results are merged with the original data file, and
                  (3) unmatched cases are included in the crosswalk (with {result:_score} and {result:_matchID} set to missing).
The following options can be used to modify these defaults:{p_end}

{phang}{opt wide} prevents the crosswalk file from being reshaped from "wide" into "long" format (and turns on {cmd:nomerge}).{p_end}

{phang}{opt nomerge} prevents the crosswalk file (in "long" format) from being merged back onto the original data.
(No merge is performed if the {cmd:wide} option is used.){p_end}

{phang}{opt missing} treats missing strings ("") in non-numeric match variables {ul:and} block variables as their own group.
See {help dtalink##remarks:remarks} below. {it:USE THIS OPTION WITH CAUTION.}
It is probably better to pre-process any missing data before running {cmd:dtalink}.{p_end}

{phang}{opt fillunmatched} fills the _matchID variable with a unique identifier for unmatched observations.
(This option is ignored when nomerge is specified.){p_end}


{dlgtab:Using options}

{phang}The {opt nol:abel} and {opt non:otes} options affect how the {help using:using {it:filename}} is appended.
See {help append} for documentation.{p_end}


{dlgtab:Display options}

{phang}{opt noweighttable} suppresses the table with the matching weights.{p_end}

{phang}{opt desc:ribe} shows a list of variables in the new data set (using the {help describe} command).{p_end}

{phang}{opt examples(#)} prints approximately # rows to the log file as examples. The default is {it:examples(0)} (no examples).{p_end}

{p2colreset} {...}


{marker remarks}{...}
{title:Remarks}

{phang}(1) Preparing data for linkage is the most important step to achieve satisfactory results (Herzog et al. 2007).
Easy data cleaning steps can greatly improve results, such as:{p_end}
{phang2}- {help string functions:Converting strings} to upper (or lower) case{p_end}
{phang2}- Splitting {help datetime:dates} and addresses into subcomponents{p_end}
{phang2}- Standardizing abbreviations and other values ({search reclink2, all:reclink2} includes helpful commands){p_end}
{phang2}- {help regexr():Removing} or standardize punctuation{p_end}
{phang2}- Using phonetic algorithms to code names (such as {help soundex()}, {search nysiis, all:nysiis}, or
{browse "https://github.com/wbuchanan/StataStringUtilities":StataStringUtilities}){p_end}

{phang}(2) Weights should reflect the probability a variable matches for true versus false matches (Fellegi and Sunter 1969).
Weights should be higher for linking variables with more specificity (like Social Security number or telephone number) and
lower for variables with less specificity (like city or age).{p_end}

{pmore}Users can estimate weights using {cmd:dtalink} and a training data file
(Execute {cmd:dtalink} on the test dataset with the  {opt calcweights} option.
Give the true matched pair identifier a large positive matching weight
and set the remaining weights to zero.)
Without training data, consider using a good linking variable (like Social Security number)
and use the {opt calcweights} to obtain recommended weights for the {it:remaining matching} variables in the same way.
More advanced techniques could be used to estimate weights (e.g., with advanced predictive analytic techniques).{p_end}

{phang}(3) To choose cutoffs, users could consider hypothetical cases.
For example, users could ask "What if records match on SSN and date of birth, but nothing else?"
Alternatively, users could start with a low cutoff, review the results, and delete pairs if a higher cutoff is needed.{p_end}

{pmore}With well-calibrated weights, a good cutoff would typically have only a few matched pairs near it, with a mix of "good" and "bad" matches.{p_end}

{pmore}Ultimately, there is no universal best approach.
Users need to carefully weigh inherent trade-offs between sensitivity and specificity with their specific data file(s).{p_end}

{phang}(4) Missing data (that is, "" for string variables or . for numeric variables) do not count as a match or a nonmatch.
That is, neither a positive nor negative weight is applied if either observation in a potential match pair has missing data for a matching variable.
However, for numeric variables, special missing codes count as a match when exact-matching.
(That is, two observations with .a match [receive the positive weight], but an observation with 5 does not match another observation with .a [receives the negative weight].)
To prevent special missing codes from being counted as a match, temporarily recode them to "." before running {cmd:dtalink}. {p_end}

{pmore}Likewise, missing data in the blocking variables usually keep observations from being compared.
If one or two observations in a potential match pair have missing data for a blocking variable,
they are not compared (unless they both have nonmissing and matching data for another blocking variable.)
However, special missing codes (such as ".a") for numeric variables would be considered a block.{p_end}

{pmore}The {cmd:missing} option overrides the default behavior for string matching variables and string blocking variables.
When this option is specified, two observations are compared if they both have missing data ("") for (one or more) block variable,
and/or they are considered to be a match if a variable is missing ("") for both observations.
{it:USE THIS OPTION WITH CAUTION}, given that it is uncommon for two records with missing values to be considered a match.{p_end}

{phang}(5) When a matching variable is specified with a numeric caliper, it uses distance matching even if the caliper is 0.
Caliper matching variables must be numeric.
Only exact matching is allowed for string variables; users are not allowed to provide a caliper for string variables.{p_end}

{pmore} Exact matching is equivalent to distance matching with caliper=0, but exact matching is usually faster.
Consider using one of the following three commands to implement exact matching: {p_end}
{phang3}{bind:(a) . dtalink var1 1 0   var2 1 0  }{p_end}
{phang3}{bind:(b) . dtalink var1 1 0 0 var2 1 0 0}{p_end}
{phang3}{bind:(c) . dtalink var1 1 0   var2 1 0 0}{p_end}

{pmore}All three commands will give the same results, but (a) may run up to 50% faster than (b) or (c).
Interestingly, testing with some data sets has shown that (b) can {it:sometimes} be faster than (c).
This is most common when many distance matching variables are specified, but very few exact matching variables are specified.{p_end}

{phang}(6) When distance matching, asymmetric calipers can be achieved by adding or subtracting a scalar from a variable in one of the two files.
For example, one project team wanted to match on a date variable and wanted to consider the dates a "match" if the date in file 0 was
within -279 days to +59 days of the date in file 1.  To achieve this, the team added "110" to the date in file 0 and used a caliper of "169," since{p_end}
{p 16 16 2 0}{bind:{txt:-279 <= (Date0 - Date1) <= 59}}{break}
             {bind:{txt:-279 + 110 <= (Date0 - Date1 + 110) <= 59 + 110}}{break}
             {bind:{txt:-169 <= (Date0 + 110 - Date1)  <= 169}}{break}
             {bind:{txt:| ( (Date0 + 110) - Date1 ) | <= 169}}{p_end}

{phang}(7) Users commonly match on a variable while also matching on a modified version of the variable. When doing this, it is important to
consider how the weights accumulate when records match on none of, some of, or all of the versions of the matching variable.{p_end}

{pmore}For example, the {search nysiis, all:nysiis} command and the following code
could be used to match on a name and the name's phonetic code:{p_end}
{phang3}{input: . nysiis name, generate(name_nysiis)}{p_end}
{phang3}{input: . dtalink name 7 0 name_nysiis 3 -2 }{p_end}

{pmore}This code would award a net weight of {p_end}
{phang3}{bind:+10} if records have the same name (+7) and therefore have the same NYSIIS code too (+3),{p_end}
{phang3}{bind: +3} if records have the same NYSIIS code (+3) but don't have the exact same name (0), and {p_end}
{phang3}{bind: -2} if records don't have the same NYSIIS code (-2) and therefore don't have the same name either (0).{p_end}

{pmore}This concept has wide-ranging applications. For example, a user could break up an address into its
subcomponents (house number, street name, city, state, zip code) and award a "bonus" score for a complete match,
or break up a Social Security number into 3-digit segments and give a "bonus" score for matching on all 9 digits. {p_end}

{pmore}Similarly, with caliper matching, users can give larger weights for a "close" match and small weights for a "far" match.
Consider the following example:{p_end}
{phang3}{input: . dtalink date 5 0 date 3 0 7 date 2 -2 30}{p_end}

{pmore}This would award a net weight of {p_end}
{phang3}{bind:+10} if date matches exactly (5+3+2),{p_end}
{phang3}{bind: +5} if date matches within 1 to 7 days (0+3+2),{p_end}
{phang3}{bind: +2} if date matches within 8 to 30 days (0+0+2), and{p_end}
{phang3}{bind: -2} if date does not match within 30 days (0+0-2).{p_end}

{phang}(8) Jaro (1995) and Winkler (1988, 1989) proposed giving larger matching weights
(in absolute value) for values that are relatively rare.
For example, users may wish to give a weight of 10 to two records that match with the last name "Kranker" but
only give a weight of  7 to two records that match with the last name "Smith."
Or, as another example, one might consider giving higher weights to a match in a small ZIP code than a
match in a large ZIP code.
This technique was not built into dtalink because it would substantially increase runtimes.

{pmore}A partial solution is to create a copy of a variable that is nonmissing for "rare" values (e.g., "Kranker")
but missing for "common" values (e.g., "Smith").
For example, the following code will give a score of +10/-7 for matches/nonmatches on "rare" names
(less than 50 rows in the data set with that name), but it will give a score of +7/-5 for matches/nonmatches on "common" names:{p_end}
{phang3}{input: . bysort name: gen name_count = _N}{p_end}
{phang3}{input: . clonevar rare_name = name if name_count <= 50}{p_end}
{phang3}{input: . dtalink name 7 -5 rare_name 3 -2 }{p_end}


{marker author}{...}
{title:Author}

{pstd}By Keith Kranker{break}
Mathematica Policy Research{p_end}

{pstd}Suggested citation{p_end}
{phang2}- Keith Kranker. "DTALINK: Stata module to implement probabilistic record linkage," Statistical Software Components S458504, Boston College Department of Economics, 2018.  Available at https://ideas.repec.org/c/boc/bocode/s458504.html.
{break}or{p_end}
{phang2}- Kranker, Keith. DTALINK: Faster Probabilistic Record Linking and Deduplication Methods in Stata for Large Data Files.” Presented at the 2018 Stata Conference, Columbus, OH, July 20, 2018.{p_end}

{pstd}I thank Liz Potamites for testing early versions of the program and providing helpful feedback.{p_end}

{pstd}Source code is available at {browse "https://github.com/kkranker/dtalink"}.
Please report issues at  {browse "https://github.com/kkranker/dtalink/issues"}.{p_end}


{marker examples}{...}
{title:Examples}

{phang}{cmd:. dtalink ssn 15 -5 lastname 3.2 -1.0 firstname 3.2 -.9 dob 6.2 -1.7 1 dob 1 -1 30 dob 1 -1 365, source(fileid) block(lastname_firstletter firstname_firstletter | ssn_first3digits) cutoff(10)}{p_end}

{phang}For more examples, see dtalink_example.do{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:dtalink} creates the following variables and stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Variables}{p_end}
{synopt:{cmd:_score}    }     probabilistic matching score{p_end}
{synopt:{cmd:_matchID } }     identification number assigned to a matched set (that is, linked records){p_end}
{synopt:{cmd:_source }  }     the source file (data linking only){p_end}
{synopt:{cmd:_id0 }     }     record identification number in file 0 (data linking only; {help dtalink##formatting:wide format} only){p_end}
{synopt:{cmd:_id1 }     }     record identification number in file 1 (data linking only; {help dtalink##formatting:wide format} only){p_end}
{synopt:{cmd:_id }      }     record identification number ({help dtalink##formatting:long format} only){p_end}
{synopt:{cmd:_matchflag}}     match indicator (0/1){p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(cutoff)}}      cutoff (minimum score that would be returned){p_end}
{synopt:{cmd:r(pairsnum)}}    number of matched pairs{p_end}
{synopt:{cmd:r(scores_mean)}} mean of scores{p_end}
{synopt:{cmd:r(scores_sd)}}   standard deviation of scores{p_end}
{synopt:{cmd:r(scores_min)}}  mininum score across all matched sets{p_end}
{synopt:{cmd:r(scores_max)}}  maximum score across all matched sets{p_end}
{synopt:{cmd:r(misscheck)}}   = 0 if nomisscheck option was specified, otherwise 1{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Strings}{p_end}
{synopt:{cmd:r(cmd)}}         {cmd:dtalink}{p_end}
{synopt:{cmd:r(cmdline)}}     command as typed{p_end}
{synopt:{cmd:r(using)}}       filename (if specified){p_end}
{synopt:{cmd:r(idvar)}}       name of {cmd:id} variable (if specified){p_end}
{synopt:{cmd:r(mtcvars)}}     list of exact matching variables (if any were specified){p_end}
{synopt:{cmd:r(mtcposwgt)}}   list of positive weights corresponding to the exact matching variables (if any were specified){p_end}
{synopt:{cmd:r(mtcnegwgt)}}   list of negative weights corresponding to the exact matching variables (if any were specified){p_end}
{synopt:{cmd:r(dstvars)}}     list of caliper matching variables (if any were specified){p_end}
{synopt:{cmd:r(dstradii)}}    list of radii corresponding to the  caliper matching variables) (if any were specified){p_end}
{synopt:{cmd:r(dstposwgt)}}   list of positive weights corresponding to the caliper matching variables (if any were specified){p_end}
{synopt:{cmd:r(dstnegwgt)}}   list of negative weights corresponding to the caliper matching variables (if any were specified){p_end}
{synopt:{cmd:r(blockvars)}}   list of blocking variables (if any were specified){p_end}
{synopt:{cmd:r(options)}}     combinesets, bestmatch, srcbestmatch(0), srcbestmatch(1), or allscores (if any of these options were specified){p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Additional results for deduplication}{p_end}
{synopt:{cmd:r(numfiles)}}     1{p_end}
{synopt:{cmd:r(N)}}            number of observations{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Additional results when linking two files}{p_end}
{synopt:{cmd:r(numfiles)}}     2{p_end}
{synopt:{cmd:r(N0)}}           number of observations in file 0{p_end}
{synopt:{cmd:r(N1)}}           number of observations in file 1{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Additional results when calcweights is specified}{p_end}
{synopt:{cmd:r(new_wgt_specs)}}  code snippet to implement recommended weights on next re-run{p_end}
{synopt:{cmd:r(new_mtc_poswgt)}} recommended (positive) weights for matches on exact matching variables{p_end}
{synopt:{cmd:r(new_mtc_negwgt)}} recommended (negative) weights for nonmatches on exact matching variables{p_end}
{synopt:{cmd:r(new_dst_poswgt)}} recommended (positive) weights for matches on caliper matching variables{p_end}
{synopt:{cmd:r(new_dst_negwgt)}} recommended (negative) weights for nonmatches on caliper matching variables{p_end}
{synopt:{cmd:r(new_weights)}}    recommended weights arranged in tabular (matrix) form{p_end}


{marker references}{...}
{title:References}

{psee}Fellegi, I. P., and A. B. Sunter. 1969. "A Theory for Record Linkage." Journal of the American Statistical Association, vol. 64, no. 328, 1969, p. 1183. doi:10.2307/2286061.{p_end}
{psee}Herzog, T. N., F. J. Scheuren, and W. E. Winkler. Data Quality and Record Linkage Techniques. New York: Springer, 2007.{p_end}
{psee}Jaro, M. A. "Probabilistic Linkage of Large Public Health Data Files." Statistics in Medicine, vol. 14, no. 5–7, 1995, pp. 491–498.{p_end}
{psee}Newcombe, H. B., J. M. Kennedy, S. J. Axford, and A. P. James. "Automatic Linkage of Vital Records." Science, vol. 130, no. 3381, October 1959, pp. 954–959.{p_end}
{psee}Winkler, W. E. "String Comparator Metrics and Enhanced Decision Rules in the Fellegi-Sunter Model of Record Linkage." Pages 354–359 in 1990 Proceedings of the Section on Survey Research. Alexandria, VA: American Statistical Association, 1990.{p_end}
