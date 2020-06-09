cd "`c(sysdir_personal)'/d"
cd ..\..\..\dtalink\code-dtalink\
cap log close dtalink_example
clear all
cls
set linesize 160
cap nois log using "dtalink_example.log", replace name(dtalink_example)

*! dtalink_example.do
*! Probabilistic record linkage routine - examples
*!
*! This progam shows how the dtalink command might be used.
*!
*! By Keith Kranker
*
* Copyright (C) Mathematica Policy Research, Inc. This code cannot be copied, distributed or used without the express written permission of Mathematica Policy Research, Inc.

pwd
about
which dtalink
set processors `c(processors_max)'


***************************************
* Examples w/ baseball players
***************************************

input byte id str8 first str6 middle str9 last byte yankee byte file
 1 "M." "" "Mantle" 1 0
 1 "Mickey" "" "Mantle" 1 0
 1 "Mickey" "" "Mantle" 1 0
 2 "Henry" "Louis" "Gehrig" 1 0
 2 "Lou" "" "Gehrig" 1 0
 3 "Babe" "" "Ruth" 1 0
 3 "George" "Herman" "Ruth, Jr." 1 0
 3 "George" "Herman" "Ruth" 0 0
 4 "Ted" "" "Williams" 0 0
 4 "Theodore" "Samuel" "Williams" 0 0
 5 "William" "Ted" "Cox" 0 0
 5 "Ted" "" "Cox" 0 0
 6 "Stan" "" "Williams" 0 0
 7 "M." "" "Mantle" 1 1
 7 "Mickey" "" "Mantle" 1 1
 8 "Henry" "Louis" "Gehrig" 1 1
 8 "Lou" "" "Gehrig" 1 1
 9 "Babe" "" "Ruth" 1 1
 9 "Babe" "" "Ruth, Jr" 1 1
 9 "George" "Herman" "Ruth, Jr" 0 1
10 "Ted" "" "Williams" 0 1
10 "Theodore" "Samuel" "Williams" 0 1
11 "William" "Ted" "Cox" 0 1
11 "Ted" "" "Cox" 0 1
12 "Stan" "" "Williams" 0 1
end

bys  file (id): list, sepby(id) noobs
preserve

// basic dedup
drop id file
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 0 -1, cutoff(4) examples(16) describe

// basic dedup - with id() variable and the "fillunmatched" option
restore, preserve
keep if file==0
drop file
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 0 -1, cutoff(4) id(id) fillunmatched describe examples(16)
cap nois list , sepby(_matchID)

// same thing with one caliper matching variable
restore, preserve
tostring id , replace format(%03.0f)
replace id = id + "XX"
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 0 -1 1, cutoff(4) id(id) fillunmatched describe examples(16) calcweights
cap nois list , sepby(_matchID)
return list

// dedup where we keep only the "best" _matchid for each id --- notice that we no longer have matches between 4 and 6, 4 and 10, 4 and 12, or 10 and 12
restore, preserve
drop file
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 0 -1, cutoff(4) id(id) bestmatch noweight
list , sepby(_matchID)

// dedup with "combined" matched sets ---  notice that 4, 6, 10, and 12 are now in a single matched set
restore, preserve
drop file
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 0 -1, cutoff(4) id(id) combinesets noweight
list , sepby(_matchID)

// dedup with  ties
restore, preserve
drop file
dtalink first 3 -3 middle 3 -3 last 3 -3 yankee 3 -3, cutoff(4) id(id) bestmatch noweight ties
list , sepby(_matchID)

// dedup with  ties
restore, preserve
drop file
dtalink first 3 -3 middle 3 -3 last 3 -3 yankee 3 -3, cutoff(4) id(id) bestmatch noweight ties  combinesets
list , sepby(_matchID)


// basic dedup - wide format
restore, preserve
keep if file==0
drop file id
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 0 -1, cutoff(4) wide nomerge describe examples(16)

// basic dedup with blocks
restore, preserve
keep if file==0
drop file id
replace yankee = . in 4/5
dtalink first 3 -3 middle 2 -1 last 6 -5 yankee 2 0, cutoff(3) block(yankee | last) describe examples(16)

// basic merge
restore, preserve
drop id
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0, cutoff(3) source(file) describe
gsort -_score _matchID file _id
list, sepby(_matchID)

// basic merge - with id() variable
restore, preserve
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0, cutoff(3) id(id) source(file) describe
list , sepby(_matchID)

// basic merge - with id() variable, keep all scores
restore, preserve
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0, cutoff(3) id(id) source(file) allscores describe
list , sepby(_matchID)
return list

// basic merge where we keep only the "best" _matchid for each id  --- notice that 4 and 12 are no longer matched together, since 4 was (only) matched to 12
restore, preserve
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0, cutoff(3) id(id) source(file) noweight bestmatch describe
list , sepby(_matchID)

// same thing with srcbestmatch(0)
restore, preserve
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0,  cutoff(3) id(id) source(file) noweight srcbestmatch(0)
list , sepby(_matchID)

// same thing with srcbestmatch(1)
restore, preserve
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0,  cutoff(3) id(id) source(file) noweight srcbestmatch(1)
list , sepby(_matchID)

// same thing with bestmatch(0) & ties & combinesets
restore, preserve
dtalink first 3 -3 middle 3 -3 last 3 -3 yankee 3 -3, cutoff(3) id(id) source(file) noweight bestmatch ties
list , sepby(_matchID)

// same thing with srcbestmatch(0)
restore, preserve
dtalink first 3 -3 middle 3 -3 last 3 -3 yankee 3 -3,  cutoff(3) id(id) source(file) noweight srcbestmatch(0) ties
list , sepby(_matchID)

// same thing with srcbestmatch(1)
restore, preserve
dtalink first 3 -3 middle 3 -3 last 3 -3 yankee 3 -3,  cutoff(3) id(id) source(file) noweight srcbestmatch(1) ties
list , sepby(_matchID)

// basic merge with "combined" matched sets --- notice that 4, 6, 10, and 12 are all matched together in a single _matchID
restore, preserve
tostring id , replace format(%03.0f)
replace id = id + "XX"
dtalink first 3 -3 middle 3 -1 last 8 -5 yankee 2 0,  cutoff(3) id(id) source(file) combinesets noweight
list , sepby(_matchID)

// basic merge with `using' syntax
restore, preserve
tempfile file2
keep if file==0
drop file
save "`file2'"

restore, preserve
drop if file==0
drop file
dtalink last 3 -3 yankee 1 -1 using "`file2'", cutoff(3) describe

// the parallel prefix might speed things up:
restore
drop if file==0
drop file
gen subsetfile = floor(_n/5)
sort subsetfile, stable
cap nois {
  parallel setclusters 2
  parallel, by(subsetfile) processors(2): dtalink last 3 -3 yankee 1 -1 using "`file2'", cutoff(3)
  tab  _score, plot
}


***************************************
* Trivial example
***************************************

clear
set obs 10
set seed 1
gen byte file = _n <= .45*_N
gen int var1 = floor(runiform()*3) if runiform()<.75
tab var1 file, mi
dtalink var1 1 0 var1 1 0 0, source(file) wide cutoff(1)
list


*********************************************
* Example with fake "birth certificate" data
*********************************************

* This program shows how the dtalink command might be used to verify the quality of a data linkage.
* Suppose someone else links a new file to (variables  dob ssn lastname and firstname) onto your
* existing dataset (variables mpr_dob mpr_ssn mpr_lastname and mpr_firstname).  After a little work to
* reshape the dataset, you can use dtalink to score each matched pairs. The trick is to use the
* block() option to restrict the matched pairs to those that were found by the other person.

clear
input byte trueID byte fileid str16 dob_str double ssn str16 lastname str9 firstname byte mofb int yofb str4 lastname_soundex str8 firstname_nysiis
      1  0  "01/05/1985"  1000000000  "Doe"  "Jane"  1  1985  "D000"  "jan"
      1  1  "01/06/1985"  1000000000  "Doe"  "Jane"  1  1985  "D000"  "jan"
      2  0  "02/07/1985"  1000000001  "Smith"  "Mary"  2  1985  "S530"  "mary"
      2  1  "02/07/1985"  .  "Smoth"  "Mary"  2  1985  "S530"  "mary"
      3  0  "05/05/1985"  1000000002  "Johnson"  "Catherine"  5  1985  "J525"  "cataran"
      3  1  "05/05/1985"  1000000002  "Jonson"  "Katie"  5  1985  "J525"  "caty"
      4  0  "05/05/1985"  1000000003  "Jones"  "Elizabeth"  5  1985  "J520"  "elasabat"
      4  1  "05/05/1985"  1000000003  "Jones"  ""  5  1985  "J520"  ""
      5  0  "01/01/1983"  .  "Sanchez"  "Maria"  1  1983  "S522"  "mar"
      5  1  "01/01/1983"  1000000004  "Sanchez-Martinez"  "Maria"  1  1983  "S522"  "mar"
      6  0  "05/05/1985"  1000000005  "Johnson"  "Jane"  5  1985  "J525"  "jan"
      6  1  "05/05/1985"  1000000005  "Johnson"  "Jane"  5  1985  "J525"  "jan"
      7  0  "11/25/1985"  1000000006  "Miller"  "Amy"  11  1985  "M460"  "any"
      8  0  "08/05/2000"  1000000007  "Miller"  "Amy"  8  2000  "M460"  "any"
      8  1  "05/01/1980"  2000000007  "Miller"  "Anne"  5  1980  "M460"  "an"
end

gen int dob = date(dob_str,"MDY")
format dob %tdN/D/CY
format ssn %12.0f
order dob, before(dob_str)
drop dob_str
label define fileid 0 "A" 1 "B"
label val fileid fileid

label var trueID           "Study ID"
label var fileid           "File A or B"
label var dob              "Date of birth"
label var ssn              "Social security number"
label var lastname         "Last name"
label var firstname        "First name"
label var mofb             "Month of birth"
label var yofb             "Year of birth"
label var lastname_soundex "Soundex code for last name"
label var firstname_nysiis "NYSIIS code for first name"

// show reshaped dataset
desc
list,sepby(trueID) noobs

preserve

// score the linkages
dtalink dob 6.2 -1.7 yofb 1 -1 mofb 1 -1 ssn 15 -5 lastname 3.2 -1.0 lastname_soundex 3.2 -.9 firstname 2.5 -1.8 firstname_nysiis 2.5 -1.7, ///
  source(fileid) cutoff(-9999) describe examples(16)
list if _matchflag!=1, sepby(_matchID)


// score the linkages with the distance() option too
restore, preserve
dtalink dob 6.2 -1.7 dob 20 0 30 dob 10 -5 365 yofb 1 -1 mofb 1 -1 ssn 15 -5 lastname 3.2 -1.0 lastname_soundex 3.2 -.9 firstname 2.5 -1.8 firstname_nysiis 2.5 -1.7, ///
  source(fileid) cutoff(-9999) describe examples(16)
list if _matchflag!=1, sepby(_matchID)

// score the linkages with only the distance() option
restore, preserve
dtalink dob 20 0 30 dob 10 -5 365 , source(fileid) cutoff(-9999) describe examples(16)
list if _matchflag!=1, sepby(_matchID)


// calc weights as if this were a training dataset
restore, preserve
dtalink trueID 1 -1 dob 0 0 30 dob 0 0 365 yofb 0 0 mofb 0 0 ssn 0 0 lastname 0 0 lastname_soundex 0 0 firstname 0 0 firstname_nysiis 0 0, source(fileid) cutoff(0) calcweight

// remove weights for trueID
local newwgts = r(new_wgt_specs)
di "`macval(_newwgts)'"
gettoken trsh newwgts : newwgts
gettoken trsh newwgts : newwgts
gettoken trsh newwgts : newwgts
di "`macval(_newwgts)'"

// see what happens when we use recommended weights
// (after picking a new cutoff)
restore
dtalink `newwgts', source(fileid) cutoff(6) bestmatch

// It worked!
sort _matchID trueID
list _matchflag _matchID trueID, sepby(_matchID)
by  _matchID (trueID): assert trueID[_n]==trueID[_N] if _matchflag


***************************************
* Short program for 1-line timers
***************************************

program define timer99
  _on_colon_parse `0'
  timer clear 99
  timer on 99
  `s(after)'
  timer off 99
  qui timer list 99
  di as txt "  Time to run = " _c
  if r(t99) < 90           di as res =round(r(t99)      ,.01) " sec"
  else if r(t99)/60 < 400  di as res =round(r(t99)/60   ,.01) " min"
  else                     di as res =round(r(t99)/60/60,.01) " hr"
  timer clear 99
end


***************************************
* Randomly generated data
***************************************

* ----------- Tall example dataset ----------

clear
set seed 1
set obs 2000
gen int x1 = floor(runiform(0,30))
gen int x2 = floor(runiform(0,30))
gen int x3 = floor(runiform(0,30))
gen x4 = cond(runiform()<.5,"male","female")
gen byte b1 = runiform()<.5
gen byte b2 = runiform()<.5
gen byte b3 = runiform()<.5
gen str2 b4 = cond(runiform()<.5,"TX","CA")
compress
local myfloor = 4


* ----------- without missing data ----------

preserve
dtalink x1 1 -1 x2 2 -2 x3 3 -3 x4 .1 -5 in 1/20, cutoff(4) describe examples(16)

restore, preserve
dtalink x1 1 -1 x2 2 -2 x3 3 -3 x4 .1 -5 in 1/20, cutoff(4) block(b1 b2 | b3 | b1 b3) describe examples(16)

restore, preserve
timer99: dtalink x1 1 -1 x2 2 -2 x3 3 -3 x4 .1 -5        , cutoff(4) describe examples(16)

restore, preserve
timer99: dtalink x1 1 -1 x2 2 -2 x3 3 -3 x4 .1 -5        , cutoff(4) block(b1 b2 | b3 | b1 b3 | b2 b4) wide describe examples(16)

restore, preserve
qui {
dtalink x1 1 -1 x2 2 -2 x3 3 -3 2 x4 .1 -5, cutoff(2) describe examples(16) calcweights
restore, preserve
dtalink `r(new_wgt_specs)'                , cutoff(2) describe examples(16) calcweights
restore, preserve
dtalink `r(new_wgt_specs)'                , cutoff(2) describe examples(16) calcweights
restore, preserve
}
dtalink `r(new_wgt_specs)'                , cutoff(2) describe examples(16) calcweights
return list

* ----------- with missing data ----------
restore
replace x1=. in 1/2
replace x2=. in 2/3
set seed 2
replace x1=. if runiform()<.05
replace x2=. if runiform()<.05

preserve
dtalink x1 1 -1 x2 2 -2 x3 3 -3 x4 .1 -2 in 1/10, cutoff(0) merge describe examples(16)
restore
timer99: dtalink x1 1 -1 x2 2 -2 x3 3 -3        , cutoff(4) merge describe examples(16)


* ----------- Wide example dataset ----------
clear
set seed 3
set obs 2000
forvalues k = 1/500 {
 gen int var`k'=floor(runiform(0,10))
 if `k' <= 100 local v1_100 `v1_100' var`k' 1 0
 local v1_500 `v1_500' var`k' 1 0
}
qui compress

preserve
dtalink `v1_100', cutoff(20) noweighttable wide describe examples(16)

restore
timer99: dtalink `v1_500', cutoff(20) noweighttable wide describe examples(16)

* ----------- Lots of blocks example ----------
clear
set seed 4
set obs 50000
forvalues k = 1/10 {
  gen var`k'=floor(runiform(0,20))
  local v1_k `v1_k' var`k' 1 0
  if `k'>4 continue
  gen blk`k' = floor(runiform(0,10000))
}
qui compress
gen f = runiform()<.5
gen g = floor(runiform(0,10))
gen dob = floor(runiform(0,400))
sort f g dob

preserve
timer99: dtalink `v1_k' , cutoff(5) block(blk1 | blk2 | blk3 | f) wide describe

restore, preserve
timer99: dtalink `v1_k' , cutoff(5) block(blk1 | blk2 | blk3) source(f) wide describe

restore, preserve
timer99: dtalink `v1_k' dob 20 0 30 dob 10 -5 365 , cutoff(5) block(blk1 | blk2 | blk3 ) noweighttable

// audit scores to see if I'm getting right results
bys _score _matchID (_id) : gen diff = abs(dob[1]-dob[_N])
by  _score _matchID (_id) : gen scoreE = (var1[1]==var1[_N])+(var2[1]==var2[_N])+(var3[1]==var3[_N])+(var4[1]==var4[_N])+(var5[1]==var5[_N])+(var6[1]==var6[_N])+(var7[1]==var7[_N])+(var8[1]==var8[_N])+(var9[1]==var9[_N])+(var10[1]==var10[_N])
by  _score _matchID (_id) : gen scoreD = cond(diff<=30, 30, cond(diff<=365, 10, -5))
gen score = scoreE + scoreD
by  _score _matchID (_id) : gen s1 = (_n==1 * runiform()<.00002)
by  _score _matchID (_id) : egen s2 = max(s1)
count if s2
// list  _* dob diff-score if s2 | score!=_score, sepby(_matchID) noobs
assert score==_score

restore, preserve
timer99: dtalink `v1_k' dob 20 0 30 dob 10 -5 365 , cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable source(f)

// the first dtalink example above takes so long because the variable f makes huge blocks. See, this takes almost as long:
restore, preserve
timer99: dtalink `v1_k', cutoff(5) block(f) wide describe

// when you only have one block, the parallel prefix might speed things up:
restore, preserve
cap nois {
  parallel setclusters 2
  timer99: ///
  parallel, by(f) processors(2):  dtalink `v1_k', cutoff(5) wide
  tab  _score, plot
}

// EM example
restore, preserve
di as input "`v1_k'"
dtalink `v1_k' dob 20 0 30 dob 10 -5 365 , cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable calcweights
di as input =r(new_wgt_specs)
restore, preserve
dtalink `r(new_wgt_specs)', cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable calcweights
restore, preserve
di as input =r(new_wgt_specs)
dtalink `r(new_wgt_specs)', cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable calcweights


restore, preserve
di as input "`v1_k'"
qui dtalink `v1_k' dob 20 0 30 dob 10 -5 365 , cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable source(f) calcweights
di as input =r(new_wgt_specs)
restore, preserve
qui dtalink `r(new_wgt_specs)', cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable source(f) calcweights
di as input =r(new_wgt_specs)
restore, preserve
dtalink `r(new_wgt_specs)', cutoff(5) block(blk1 | blk2 | blk3 ) wide noweighttable source(f) calcweights

return list

log close dtalink_example
