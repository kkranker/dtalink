*! dtalink.ado
*! Probabilistic record linkage or deduplication
*
*  dtalink implements probabilistic record linkage (a.k.a. probabilistic matching) for two cases:
*   - deduplicating records in one data file
*   - linking records in two data files (requires using or source())
*
*  For each matching variable, you can use two different methods to compare two observations in a potential match pair:
*  - "Exact" matching awards positive weights if (X for observation 1)==(X for observation 2), and awards negative points otherwise.
*  - "Caliper matching" awards positive weights if | (X for observation 1)-(X for observation 2)|<=threshold, and awards negative points otherwise.
*
*  The project's main goal was speed: to quickly implement "standard" linkage techniques with large
*  datasets. The computationally-heavy parts of the program are implemented in Mata subroutines.
*
*! By Keith Kranker
*
* dtalink.sthlp includes a full description of the command, the command's sytnax, and description of each outcome.
*
* See dtalink_example.do for examples.
*
* Copyright (C) Mathematica Policy Research, Inc. This code cannot be copied, calipributed or used without the express written permission of Mathematica Policy Research, Inc.

program define dtalink, rclass
  version 15.1
  return clear
  return local cmd     "dtalink"
  return local cmdline `"dtalink `0'"'

  syntax anything(id="matching criteria")   /// list of exact-matching variables or (mvar1 #1 #2 [#3]) [(mvar2 #1 #2 [#3]) [(mvar3 #1 #2 [#3]) [...]]]
    [if] [in]               /// standard data restrictions
    [using] [,              /// appends new file onto using dataset and creates dummy for source()
                            ///
    /// Matching Options
    Source(varname)         /// idenfities the source file for record linkage. That is, cases where you are going to link records in file A to file B. varname must be a dummy = 0/1.
    id(varname)             /// Variable to identify unique observations. there may be more than one record (row) per observation (e.g., more than one record [row] per person [observation])
                            ///     The default is to  treat each row as a unique observation, by creating an id variable with this command:  . generate _id = _n
                            ///     If the variable specified is missing, the record will not be included.
    CUToff(real 0)          /// drops potential matched pairs if the score is below the cutoff.  The default is cutoff(0).
    Block(string)           /// declares blocking variables.  If multiple variables listed, each unique combinations of the variables is considered a block.  (No variable name abbreviations allowed.)
                            ///     To specify multiple sets of blocks, separate blocking variables with "|", such as block(bvar1 | bvar2 bvar3 | bvar4)
    CALcweights             /// calculate weights
    BESTmatch               /// drop 2nd-best matches.  See notes below.
    SRCBESTmatch(integer -1) /// drop 2nd-best matches for source=0 observations or source=1 observations (but not both). See notes below.
    TIEs                    /// keeps ties when bestmatch and scrbestmatc() are otherwise dropping 2nd-best matches
    COMBINEsets             /// creates extra large groups that may contain more than one id(). See notes below.
    ALLScores               /// keeps all scores for a pair, not just the maximum score (By default, the program only keeps the max score for a matched pair.  This option keeps all scores for a pair. (This only has an effect on the results if id() is not unique.) (implies nomerge)
                            ///
    /// OPTIONS TO FORMAT OUTPUT
    WIde                    /// do not reshape file from "wide" into "long" format (implies nomerge).
    noMErge                 /// do not merge (the "long" file) back onto original data
    MISSing                 /// treats missing strings ("") in match variables that are strings {ul:and} block variables as their own group.  Use with caution. See remarks below.
    FILLunmatched           /// fills the _matchID variable with a unique identifier for unmatched observations (this option is ignored when nomerge is specified.)
                            ///
    /// Using options
    noLabel nonotes         /// options for appending the using dataset; options are ignored if using file not provided
                            ///
    /// Display options
    noWEIghttable           /// supresses the table with the matching weights
    DESCribe                /// show a list of variables in the new dataset
    examples(numlist integer max=1 >0) /// print # examples; the default is examples(0) (no examples)
                            ///
    /// undocumented
    noMISSCheck             /// checks for missing data once (instead of checking for each block)
    debug                   ///
    ]

  // Missing data (that is, "" for string variables or . for numeric variables) do not count as a match or a non-match.
  // Likewise, missing data in the block variables keeps observations from being compared.
  // If one or two observations in a potential match pair have missing data, neither a positive or negative weight is applied.
  // However, for numeric variables, special missing codes do count as a match (e.g., two observations with .a are considered a match, but an observation with 5 does not match another observation with .a).
  // The missing option overrides this behavior for string matching variables and blocking variables.
  // Two observations are compared if they are both missing data for (one or more) block variable, and/or are considered to be a match if a variable is missing for both observations.  USE THIS OPTION WITH CAUTION.{p_end}{p_end}

  // using option
  if (`"`using'"'!="") {
    if (`"`source'"'!="") {
      di as error "source() option not allowed with " in smcl "{help using}"
      error 184
    }
    confirm new variable _file
    local   source _file
    append `using', generate(`source') `label' `notes'
    cap label define `source' 0 "master" 1 "using", add
    label val `source' `source'
    label var `source' "0=master; 1=using"
    return local using `"`using'"'
  }

  // identify sample using `if' `in' from standard syntax
  marksample touse, novarlist
  confirm new variable _id _id0 _id1 _score _matchID _source

  // no ID provided
  if ("`id'"=="") {
    gen _id = _n
    label var _id "Row number in original data file"
    local id _id
  }

  // handle string IDs
  else {
    return local idvar = "`id'"
    cap confirm numeric var `id'
    if _rc {
      if ("`wide'"=="wide" | "`merge'"=="nomerge") {
        nois di as error "String id() variable not allowed with -wide- and -nomerge- options. Try converting `id' to a numeric variable."
        error 108
      }
      qui egen _id = group( `id' ) if `touse' & !mi(`id')
      if !mi(`"`: var label `id''"') label var _id `"`: var label `id''"'
      else                           label var _id "`id'"
      local idvar : copy local id
      local id _id
    }
  }
  local id_label : var label `id'

  // with 2 files, check/prepare the `source' variable
  sort `source' `id', stable
  if ("`source'"!="") {
    // check `source' is a dummy
    cap assert inlist(`source',0,1) if `touse'
    if _rc {
      di as error "`source' must equal 0 or 1 for all records."
      error 459
    }
    return scalar numfiles = 2

    // see which file has fewer unique IDs
    tempvar idtag
    qui egen byte `idtag'= tag(`source' `id') if `touse'
    qui count if `idtag' & !`source'
    local n_ids_0 = r(N)
    qui count if `idtag' & `source'
    local n_ids_1 = r(N)
    drop `idtag'

    // throw error if `source' is always 0 or always 1
    if (inlist(`n_ids_0',.,0) | inlist(`n_ids_1',.,0)) {
      di as error "source(`source') must equal 0 for at least one record and equal 1 for at least one record."
      error 459
    }

    // if source=1 is smaller than source=0, swap the two values so that file "0" has fewer IDs
    // in the typical case, this should cause more computations to happen in parallel
    else if (`n_ids_1'<`n_ids_0') {
      // di as txt "  (`source'=0 has more unique IDs than `source'=1. Temporarily creating new source variable = (!`source')."
      qui gen byte _source = !`source' if `touse'
      local sourcevar : copy local source
      local source _source
    }
  }
  else {
    return scalar numfiles = 1
  }

  // for "merge" option, save a temporary copy of the file
  if ("`wide'"=="wide" | "`allscores'"=="allscores") local merge nomerge
  if ("`merge'"!="nomerge" ) {
    tempfile sourcefile
    sort `source' `id', stable
    qui save `sourcefile'
  }

  // As `anything' gets parsed, I will create the table I want to display (with tabdisp) in these temporary variables
  if ("`weighttable'"!="noweighttable") {
    tempvar mv1 mv2 mv3 mv4 mv5
    qui gen `mv1'  = ""
    qui gen `mv2'  = .
    qui gen `mv3'  = .
    qui gen `mv4'  = .
    qui gen `mv5'  = ""
    label var `mv1' "variable name"
    label var `mv2' "Match weight"
    label var `mv3' "No match weight"
    label var `mv4' "Caliper"
    label var `mv5' "Usage type"
    local tablerow = 0
  }

  // Parse `anthing'
  tokenize `anything'
  while (`"`1'"' != "") {
    confirm variable `1'
    confirm number   `2'
    confirm number   `3'
    cap assert inrange(`2',0,.) & (`3'<=0)
    if _rc {
      di as error `"`1' `2' `3' invalid"'
      error 198
    }
    if ("`weighttable'"!="noweighttable") {
      if c(N)<=`++tablerow' qui set obs `tablerow'
      qui replace `mv1'  = trim(`"`1'"') in `tablerow'
      qui replace `mv2'  = `2'           in `tablerow'
      qui replace `mv3'  = `3'           in `tablerow'
    }
    cap confirm number `4'
    if !_rc {
      confirm numeric variable `1'
      cap assert (`1'<=.) if `touse'
      if _rc {
        misstable summarize `1'
        di as error `"Special missing codes (.a, .b, ... , .z) not allowed with caliper matching variables. Consider changing these observations to ."'
        error 416
      }
      cap assert inrange(`4',0,.)
      if _rc {
        di as error `"`1' `2' `3' `4' invalid"'
        error 198
      }
      local calipvars    `calipvars'   `1'
      local calipposwgt  `calipposwgt' `2'
      local calipnegwgt  `calipnegwgt' `3'
      local calipers     `calipers'    `4'
      if ("`weighttable'"!="noweighttable") {
        qui replace `mv4'  = `4'       in `tablerow'
        qui replace `mv5'  = "Caliper matching variables" in `tablerow'
      }
      mac shift 4
    }
    else {
      local varlist     `varlist'    `1'
      local posweights  `posweights' `2'
      local negweights  `negweights' `3'
      if ("`weighttable'"!="noweighttable") {
        qui replace `mv4' = 0 in `tablerow'
        qui replace `mv5' = "Exact matching variables" in `tablerow'
      }
      mac shift 3
    }
  }

  // return key inputs in r()
  return scalar cutoff = `cutoff'
  return scalar misscheck = ("`misscheck'"!="nomisscheck")
  if ("`varlist'"!="") {
    return local mtcvars   = "`varlist'"
    return local mtcposwgt = "`posweights'"
    return local mtcnegwgt = "`negweights'"
  }
  if ("`calipvars'"!="") {
    return local dstvars   = "`calipvars'"
    return local dstradii  = "`calipers'"
    return local dstposwgt = "`calipposwgt'"
    return local dstnegwgt = "`calipnegwgt'"
  }
  if ("`block'"!="") {
    return local blockvars  = "`block'"
  }

  // add blocking variables to output table, but don't do anything else (yet)
  if ("`weighttable'"!="noweighttable") {
    if (`"`block'"'!="") {
      tokenize `"`block'"', parse("|")
      while (`"`1'"' != "") {
        if (trim(`"`1'"') != "|") {
          if c(N)<=`++tablerow' qui set obs `tablerow'
          qui replace `mv1'  = trim(`"`1'"') in `tablerow'
          qui replace `mv4'  = 0 in `tablerow'
          qui replace `mv5'  = "Blocking variables" in `tablerow'
        }
        mac shift
      }
    }
    else {
      if c(N)<=`++tablerow' qui set obs `tablerow'
      qui replace `mv1'  = `"(None)"' in `tablerow'
      qui replace `mv4'  = 0 in `tablerow'
      qui replace `mv5'  = "Blocking variables" in `tablerow'
    }
  }

  // check for invalid options or combinations of options
  if ("`ties'"=="ties") {
    if (1 != ("`bestmatch'"=="bestmatch") + inlist(`srcbestmatch',0,1)) {
      di as error "With the `ties' option, you are required to select one of the following options: bestmatch, srcbestmatch()."
      error 184
    }
    else if ("`allscores'"=="allscores") {
      di as error "With the `ties' option, allscores is not allowed."
      error 184
    }
  }
  else if (1<(("`combinesets'"=="combinesets") + ("`bestmatch'"=="bestmatch") + inlist(`srcbestmatch',0,1) + ("`allscores'"=="allscores"))) {
    di as error "Only one of the following options is allowed at a time: combinesets, bestmatch, srcbestmatch(), and allscores."
    error 184
  }
  else return local options = trim(`"`combinesets' `bestmatch' `ties' `=cond(inlist(`srcbestmatch',0,1),"srcbestmatch(`srcbestmatch')","")' `allscores'"')
  if !inlist(`srcbestmatch',-1) {
    if !inlist(`srcbestmatch',0,1) {
      di as error "srcbestmatch() option must be 0 or 1"
      error 198
    }
    if ("`source'"=="") {
      di as error "srcbestmatch() option only allowed for record linkage (two files)"
      error 184
    }
  }
  local allvars : list uniq varlist
  if (!`: list allvars === varlist') {
    di as error `"`: list dups varlist' listed in varlist more than once"'
    error 198
  }
  if (`"`block'"'!="") {
    local blockvars : subinstr local block "|" " ", all
    cap confirm var `blockvars', exact
    if _rc {
      di as error "One or more variables listed in block() were not found in the data." _n "Note that variable abbreviations are not allowed in the block() option.)"
      confirm var `blockvars', exact
    }
  }
  local calcweights = ("`calcweights'"=="calcweights") // switch to dummy

  // print matching variables to screen
  if ("`weighttable'"!="noweighttable") {
    sort `mv1' `mv5' `mv4' `mv3' `mv2', stable
    qui by `mv1' (`mv5' `mv4' `mv3' `mv2'): replace `mv1' = `mv1' + " (" + strofreal(_n) + ")" if _N > 1 & !mi(`mv1')
    tabdisp `mv1' if !mi(`mv1'), cellvar(`mv2' `mv3' `mv4') by(`mv5') concise
  }

  // drop duplicates
  unab  allvars : `id' `varlist' `calipvars' `blockvars' `source' `touse'
  qui keep `allvars'
  qui keep if `touse'
  qui duplicates drop

  // convert any strings to (temporary) numeric variables
  // `mtcvarlist' is the same as `varlist' but we replace the old variable name with the temporary variable's name
  // `numblock' is the same as `block' but we replace the old variable name with the temporary variable's name
  // `calipvars' doesn't need to be checked since we already know the variable is numeric (see above)
  local mtcvarlist: copy local varlist
  local numblock:   copy local block
  local allvars : list uniq allvars
  cap confirm numeric var `allvars', exact
  if _rc {
    foreach v of local allvars {
      cap confirm numeric var `v', exact
      if !_rc continue
      tempvar _`v'
      qui egen `_`v'' = group( `v' ) , `missing'
      local mtcvarlist : subinstr local mtcvarlist "`v'" "`_`v''" , word all
      local numblock   : subinstr local numblock   "`v'" "`_`v''" , word
    }
  }

  // do not compare records where the id variable is missing
  qui count if `touse' & mi(`id')
  if (r(N)) {
    di as res =r(N) as txt " records dropped because missing value(s) in `id'"
    qui replace `touse' = 0 if mi(`id') & `touse'
  }

  // one copy of `touse' for each file
  if ("`source'"!="") {
    tempvar touse_f0 touse_f1
    qui gen byte `touse_f0' = `touse' & !`source'
    qui gen byte `touse_f1' = `touse' &  `source'
    qui count if `touse_f0'
    if (!r(N)) error 2000
    return scalar N0 = r(N)
    qui count if `touse_f1'
    if (!r(N)) error 2000
    return scalar N1 = r(N)
  }
  else {
    local touse_f0 : copy local touse
    qui count if `touse'
    if (!r(N)) error 2000
    return scalar N = r(N)
  }

  // create three empty variables to hold the results
  // variables have the same type as ID; scores are double
  qui gen double _matchID = .
  label var _matchID "Matched set identifier"
  qui compress `id'
  qui clonevar _id0 = `id' if 0
  qui clonevar _id1 = `id' if 0
  qui gen double _score = .
  format _score %9.2f
  label var _score   "Probabilistic matching score"

  // when de-duping, sort larger groups to the top
  sort `source' `id', stable
  if ("`source'"=="") {
    tempvar id_n rownum
    gen `rownum' = _n
    qui by `id': gen byte `id_n'= _N if `touse'
    gsort `source' -`id_n' `id' `rownum'
    drop `id_n' `rownum'
  }

  // -- -block- option --
  // setup the blocking commands by creating a series of numeric variables with the egen() command
  // (if no blocking variables, then `block_id_list' is empty)
  local b=0
  if (`"`block'"' != "") {
    while (`"`block'"'!="") {

      // get the blocking set (until we run out)
      local ++b
      gettoken blockvars block : block, parse("|")
      gettoken waste     block : block, parse("|")
      confirm var `blockvars'
      gettoken numblockvars numblock : numblock, parse("|")
      gettoken waste        numblock : numblock, parse("|")
      local blockvars = trim(`"`blockvars'"')
      local numblockvars  = trim(`"`numblockvars'"')
      confirm var `blockvars', exact
      confirm var `numblockvars', exact

      // setup variable to block on; find number of blocks
      if (`: list sizeof numblockvars'==1) {
        local block_id_`b': copy local numblockvars
      }
      else {
        tempvar block_id_`b'
        qui egen `block_id_`b'' = group( `numblockvars' ) if `touse' , `missing'
      }
      local `block_id_`b''_label = `"`"`blockvars'"'"'
      local block_id_list : list block_id_list | block_id_`b'
      local block_lab_list : list block_lab_list | `block_id_`b''_label
      mac drop _`block_id_`b''_label
    } // end of loop through block variables
  } // end of -block- option setup

  // MAIN ALGORITHM IS IMPLEMENTED IN MATA
  // get a class instance
  tempname D

  // copy data and other matching parameters to mata
  if ("`source'"=="") {
    mata: `D' = dtalink()
  }
  else {
    mata: `D' = dtalink2()
  }

  // move local macros and data from Stata into Mata
  mata: `D'.load()
  keep _id0 _id1 _score _matchID
  qui keep in 1

  // run the linkage
  mata: `D'.probabilisticlink(`calcweights')

  // remove duplicates, sort, assign IDs
  mata: `D'.dedup("`allscores'"=="")
  mata: `D'.assign()

  // Re-calucate weights using the pairs that were found,
  // and then re-run matching and recalculate weights.
  // Repeat until no matches are found or the maximum number of loops is reached.
  if (`calcweights') {
    tempname wtab
    local lastN = r(pairsnum)
    di as txt _n "Suggested matching weights:"
    mata: `D'.newweights()
    matrix `wtab' = r(new_weights)
    return add
    _matrix_table `wtab', format(%9.3f %9.3f `=cond(trim("`calipvars'")!="","%9.3f","")')
  }

  // deal with case of no matches found
  if (r(pairsnum)==0) {
    if ("`merge'"!="nomerge" ) {
      nois di as txt "(Restoring the data.)"
      qui use `sourcefile',clear
      cap drop _id
      if ("`sourcevar'"!="") {
        drop _source _id
        local source : copy local sourcevar
      }
    }
    exit
  }

  // The bestmatch option deals with case where an `id' is assigned to multiple _matchIDs.
  // After running this subroutine, each `id' will be assigned to exactly one _matchID.
  if ("`bestmatch'"=="bestmatch" & "`ties'"=="ties") {
    mata: `D'.dropinferior()
  }
  else if ("`bestmatch'"=="bestmatch" & "`ties'"=="") {
    mata: `D'.bestmatch()
  }

  // The srcbestmatch() option deals with case where an `id' in one file (0 or 1) is assigned to multiple _matchIDs.
  // For each `id' in file=`srcbestmatch', we keep each _matchIDs with the highest score.
  else if inlist(`srcbestmatch',0,1)  & "`ties'"=="ties" {
    local adj_srcbestmatch = cond("`sourcevar'"!="",1-`srcbestmatch',`srcbestmatch') // we might have switched left/right above
    mata: `D'.dropinferior(`adj_srcbestmatch')
  }
  else if inlist(`srcbestmatch',0,1)  & "`ties'"=="" {
    local adj_srcbestmatch = cond("`sourcevar'"!="",1-`srcbestmatch',`srcbestmatch') // we might have switched left/right above
    mata: `D'.bestmatch(`adj_srcbestmatch')
  }

  // combinesets is a subroutine to deal with case where an ID is assigned to multiple _matchIDs.
  // After running this subroutine, _matchID be updated to include all IDs that were ever matched together
  if ("`combinesets'"=="combinesets") {
    mata: `D'.combinesets()
  }

  // move results back into Stata
  mata: `D'.extract("_id0 _id1 _score _matchID")
  mata: st_local("pairsnum",strofreal(`D'.pairsnum))
  return scalar pairsnum = `pairsnum'
  qui compress _score _matchID

  // drop the class instance
  mata: mata drop `D'

  // summary stats on scores
  di as txt _n "Distribution of matched pair scores, among pairs with score >=`cutoff':"
  qui inspect _score
  if (r(N_unique)<30) {
    tab  _score, plot
    qui sum _score
  }
  else {
    summ _score, det
  }
  return scalar scores_mean = r(mean)
  return scalar scores_sd   = r(sd)
  return scalar scores_min  = r(min)
  return scalar scores_max  = r(max)

  if ("`combinesets'"=="combinesets") {
   qui {
      gen row = _n
      if ("`source'"=="") {
        reshape long _id, i(row)
        drop row _j
      }
      else {
        reshape long _id, i(row) j(`source')
        drop row
      }
      collapse (max) _score, by(_matchID _id `source')
      rename _id `id'
      label var `id' `"`id_label'"'
      sort  _matchID `source' `id', stable
      order _matchID `source' `id', first
    }
    di as txt "The current configuration of the data is: one row per record."
  }

  // if `wide' option, just leave in wide format
  else if ("`wide'"=="wide") {
    if ("`sourcevar'"!="") {
      rename (_id0 _id1) (_id1 _id0)
      order _id0, before(_id1)
    }
    di as txt "The current configuration of the data is: one row per matched pair."
  }

  // reshape into long format
  else {
    qui {
      if ("`source'"=="") {
        reshape long _id, i(_matchID)
        drop _j
      }
      else {
        reshape long _id, i(_matchID) j(`source')
      }
      rename _id `id'
      label var `id' `"`id_label'"'
      sort  _matchID `source' `id', stable
      order _matchID `source' `id', first
    }
    di as txt "The current configuration of the data is: one row per record."
  }

  // merge option -- 1:n merge with the original file
  if ("`merge'"!="nomerge") {
    sort `source' `id', stable
    gen byte `touse'=1
    qui joinby `source' `id' `touse' using `sourcefile', _merge(_matchflagtemp) unmatched(both)
    gen byte _matchflag = _matchflagtemp==3
    drop  _matchflagtemp
    if ("`sourcevar'"!="") {
      drop _source
      local source : copy local sourcevar
    }
    if ("`idvar'"!="") {
      drop _id
      local id : copy local idvar
    }
    sort _matchID `source' `id' `calipvars' `varlist', stable
    order _matchID `source' `id' _score _matchflag, first
    label var _matchID "Matched set identifier"
    if (`"`using'"'!="") label var _file "0=master dataset; 1=using dataset"
    cap assert (_matchflag==!missing(_matchID))  // at this point, only matched observations have _matchID filled in
    if _rc {
      di as error "Programming error 1"
      list if (_matchflag!=!missing(_matchID))
      assert (_matchflag==!missing(_matchID))
    }

    // `fillunmatched' fills the _matchID variable with a unique identifier for unmatched observations (this option is ignored when nomerge is specified.)
    if ("`fillunmatched'"=="fillunmatched") {
      tempvar groupid
      egen `groupid' = group(`source' `id') if !missing(`id') & `touse'
      summ _matchID, mean
      qui replace _matchID = r(max) + `groupid' if _matchflag!=1 & !missing(`id') & `touse'
      drop `groupid'
      sort _matchID `source' `id' `calipvars' `varlist', stable
      qui count if missing(_matchID)
      if r(N) di as error r(N) " observations have missing _matchID." as txt " This is typically due to missing values in the ID variable (`id')."
    }
    drop `touse'
  }
  else {
    gen byte _matchflag=1
  }
  cap label define _mtchflg     1 "Matched" 0 "Not matched"
  label val    _matchflag _mtchflg
  label var    _matchflag   "Match indicator"

  // describe output file (a little)
  if ("`describe'"=="describe") {
    di _n(2) as text "Description of the new dataset:"
    desc
  }

  // print examples
  if ("`examples'"!="") {
    di as txt _n "Examples (up to `examples' rows):"
    if "`wide'"=="wide" list if _matchID<=_matchID[`=min(`examples',c(N))'] & `=cond("`merge'"=="nomerge","!missing(_matchID)","_matchflag==1")', sepby(_id0)
    else                list if _matchID<=_matchID[`=min(`examples',c(N))'] & `=cond("`merge'"=="nomerge","!missing(_matchID)","_matchflag==1")', sepby(_matchID)
  }

end   // end of dtalink program definition



*! Mata Source Code
*! Defines classes which are called by dtalink.ado
*! dtalink is the parent class and includes shared functions
*! dtalink is used for deduplicating 1 file
*! dtalink2 extends dtalink for the case of linking 2 files
*! some functions in dtalink are replaced in the derived class, dtatlink2

version 15.1
mata:
mata set matastrict on
mata set matafavor speed

class dtalink
{
  // moving between Stata and matastrict
  public:
    void           load()
    void           updateweights()
    void           extract()

  // linking criteria setup
  protected:
    string scalar  id_var
    string vector  mtc_vars
    string vector  mtc_vars_num
    string vector  dst_vars
    real scalar    mtc_num
    real scalar    dst_num
    real colvector mtc_poswgt
    real colvector mtc_negwgt
    real rowvector dst_radii
    real colvector dst_poswgt
    real colvector dst_negwgt
    real scalar    cutoff

  // file0
  protected:
    string scalar  selectrows_0
    real scalar    num_0
    real colvector ids_0
    real matrix    mtc_0
    real matrix    dst_0
    real matrix    block_0

  // blocking setup
  protected:
    string vector  block_vars
    string vector  block_labs
    real scalar    num_block_vars

  // functions and variables used in matching
  public:
    real matrix    pairs
    real scalar    pairsnum
    void           clearpairs()
    void           probabilisticlink()
    void           dedup()
    void           assign()
    void           bestmatch()
    void           dropinferior()
    void           combinesets()
    real matrix    tall()
  protected:
    void           new()
    virtual void   link_one_block_var()
    virtual void   link_one_block()
    transmorphic   colvector intersect()
    void           store_pairs()
    real colvector mtc_score()
    real colvector dts_score()
    real scalar    check_miss, mtc_miss, dst_miss, pairmatnum, initrows
    real matrix    mtc_match, mtc_ijnonmiss, dst_match, dst_ijnonmiss

  // variables to perform em calculations
  public:
    void           clearsums()
    void           newweights()
    real colvector new_mtc_poswgt, new_mtc_negwgt, new_dst_poswgt, new_dst_negwgt
  protected:
    real scalar    runsum_1_N, runsum_0_N
    real rowvector mtc_runsum_1, mtc_runsum_0, dst_runsum_1, dst_runsum_0

  //DEBUG// // dummy to get extra output when debugging
  //DEBUG// protected:
  //DEBUG//   real scalar    debug
}

class dtalink2 extends dtalink
{
  public:
    void           load()
    void           bestmatch()
    void           dropinferior()
    void           combinesets()

  protected:
    virtual void   link_one_block_var()
    virtual void   link_one_block()

  // file 1
  protected:
    string scalar  selectrows_1
    real scalar    num_1
    real colvector ids_1
    real matrix    mtc_1
    real matrix    dst_1
    real matrix    block_1
}

// dta::new() initializes the matrices and scalars that hold the results
void dtalink::new()
{
  clearpairs()
}

// dta::clearpairs() clears the matrices and scalars that hold the results, without removing any of the inputs
void dtalink::clearpairs() {
  pairs    = J(0,3,.)
  pairsnum = pairmatnum = 0
}

// resets matrices that are used to calculate running sums for computing EM weights
void dtalink::clearsums() {
  new_mtc_poswgt = new_mtc_negwgt = J(mtc_num,1,.)
  new_dst_poswgt = new_dst_negwgt = J(dst_num,1,.)
  mtc_runsum_1  = mtc_runsum_0  = J(1,mtc_num,0)
  dst_runsum_1  = dst_runsum_0  = J(1,dst_num,0)
  runsum_1_N    = runsum_0_N    = 0
}

// dtalink::load() will
// 1) copy relevant Stata local macros into class variables and
// 2) copy the data for file 0 into the class instance.
// It assumes locals are set up the same was as in the .ado file
void dtalink::load()
{
  //DEBUG// debug = (st_local("debug")=="debug")
  //DEBUG// if (debug) "+++ debug is [on]"
  //DEBUG// if (debug) "+++ beginning of dtalink::load()"

  // basic setup
  id_var       = tokens(st_local("id"))
  cutoff       = strtoreal(st_local("cutoff"))
  check_miss   = st_local("misscheck")!="nomisscheck"

  // exact matching setup
  mtc_vars     =  tokens(st_local("varlist"))     // this has string variables
  mtc_vars_num =  tokens(st_local("mtcvarlist"))  // string variables converted to numeric
  mtc_num  = length(mtc_vars)
  if (mtc_num) {
    mtc_poswgt = strtoreal(tokens(st_local("posweights")))'
    mtc_negwgt = strtoreal(tokens(st_local("negweights")))'
  }
  else mtc_vars = J(1,0,"")

  // caliper matching setup
  dst_vars = tokens(st_local("calipvars"))
  dst_num  = length(dst_vars)
  if (dst_num) {
      dst_radii  = strtoreal(tokens(st_local("calipers" )))
      dst_poswgt = strtoreal(tokens(st_local("calipposwgt")))'
      dst_negwgt = strtoreal(tokens(st_local("calipnegwgt")))'
  }
  else dst_vars = J(1,0,"")

  // blocking setup
  block_vars  = tokens(st_local("block_id_list"))
  block_labs  = tokens(st_local("block_lab_list"))
  num_block_vars = (length(block_vars))

  //DEBUG// if (debug) {
  //DEBUG//   "id_var=";          id_var
  //DEBUG//   "cutoff=";         cutoff
  //DEBUG//   "mtc_num=";        mtc_num
  //DEBUG//   if (mtc_num) {
  //DEBUG//     "mtc_vars=";     mtc_vars
  //DEBUG//     "mtc_vars_num="; mtc_vars_num
  //DEBUG//     "mtc_poswgt=";   mtc_poswgt
  //DEBUG//     "mtc_negwgt=";   mtc_negwgt
  //DEBUG//   }
  //DEBUG//   "dst_num=";        dst_num
  //DEBUG//   if (dst_num) {
  //DEBUG//     "dst_vars=";     dst_vars
  //DEBUG//     "dst_radii=";    dst_radii
  //DEBUG//     "dst_poswgt=";   dst_poswgt
  //DEBUG//     "dst_negwgt=";   dst_negwgt
  //DEBUG//   }
  //DEBUG//   "num_block_vars="; num_block_vars
  //DEBUG//   if (num_block_vars) {
  //DEBUG//     "block_vars=";   block_vars
  //DEBUG//   }
  //DEBUG// }

  // load file 0
  selectrows_0 = tokens(st_local("touse_f0"))
  ids_0 = st_data(., id_var, selectrows_0)
  num_0 = rows(ids_0)
  if (mtc_num)        mtc_0   = st_data(., mtc_vars_num, selectrows_0)
  else                mtc_0   = J(num_0,0,.)
  if (dst_num)        dst_0   = st_data(., dst_vars, selectrows_0)
  else                dst_0   = J(num_0,0,.)
  if (num_block_vars) block_0 = st_data(., block_vars, selectrows_0)
  else                block_0 = J(num_0,0,.)
  initrows = length(ids_0)*5

  // dummy for having missing data (calculations are quicker if data is never missing)
  if (mtc_num)    mtc_miss = hasmissing(mtc_0)
  if (dst_num)    dst_miss = hasmissing(dst_0)

  // setup running sum matrices know that mtc_num and dst_num are set
  clearpairs()
  clearsums()

  //DEBUG// if (debug) {
  //DEBUG//   "selectrows_0=";  selectrows_0
  //DEBUG//   "mtc_0   is " + strofreal(rows(mtc_0  )) + " by " + strofreal(cols(mtc_0  ))
  //DEBUG//   "dst_0   is " + strofreal(rows(dst_0  )) + " by " + strofreal(cols(dst_0  ))
  //DEBUG//   "block_0 is " + strofreal(rows(block_0)) + " by " + strofreal(cols(block_0))
  //DEBUG//   "pairs   is " + strofreal(rows(pairs  )) + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "+++ end of dtalink::load()"
  //DEBUG// }
}

// dtalink::updateweights() allows you to upadte class variables
// mtc_poswgt, mtc_negwgt, dst_poswgt, and dst_negwgt
// Inputs must be same shape as original weight vectors.
// Use . or J(0,1,.) if only using exact-or caliper matching.
void dtalink::updateweights(real colvector new_mtc_poswgt,
                            real colvector new_mtc_negwgt,
                            real colvector new_dst_poswgt,
                            real colvector new_dst_negwgt)
{
  if (rows(new_mtc_poswgt) & new_mtc_poswgt!=.) {
    if (rows(new_mtc_poswgt)!=mtc_num) _error(3200)
    this.mtc_poswgt = new_mtc_poswgt
  }
  if (rows(new_mtc_negwgt) & new_mtc_negwgt!=.) {
    if (rows(new_mtc_negwgt)!=mtc_num) _error(3200)
    this.mtc_negwgt = new_mtc_negwgt
  }
  if (rows(new_dst_poswgt) & new_dst_poswgt!=.) {
    if (rows(new_dst_poswgt)!=dst_num) _error(3200)
    this.dst_poswgt = new_dst_poswgt
  }
  if (rows(new_dst_negwgt) & new_dst_negwgt!=.) {
    if (rows(new_dst_negwgt)!=dst_num) _error(3200)
    this.dst_negwgt = new_dst_negwgt
  }
}

// dtalink2::load() will
// 1) copy relevant Stata local macros into class variables.
// 2) copy the data for file 0 into the class instance (by calling dtalink::load()) and
// 3) copy the data for file 1 into the class instance.
// It assumes locals are set up the same was as in the .ado file
void dtalink2::load()
{
  // load file 0 and most of the macros
  super.load()

  //DEBUG// if (debug) "+++ beginning of dtalink2::load() (after calling super.load)"

  // file 1 touse variable
  selectrows_1 = st_local("touse_f1")

  // load file 1
  ids_1 = st_data(., id_var, selectrows_1)
  num_1 = rows(ids_1)
  if (mtc_num)        mtc_1   = st_data(., mtc_vars_num, selectrows_1)
  else                mtc_1   = J(num_1,0,.)
  if (dst_num)        dst_1   = st_data(., dst_vars, selectrows_1)
  else                dst_1   = J(num_1,0,.)
  if (num_block_vars) block_1 = st_data(., block_vars, selectrows_1)
  else                block_1 = J(num_1,0,.)
  initrows = min((initrows,length(ids_1)*5))

  // dummy for having missing data (calculations are quicker if data is never missing)
  if (mtc_num)    mtc_miss = ( mtc_miss | hasmissing(mtc_1) )
  if (dst_num)    dst_miss = ( dst_miss | hasmissing(dst_1) )

  //DEBUG// if (debug) {
  //DEBUG//   "selectrows_1="; selectrows_1
  //DEBUG//   "mtc_1   is " + strofreal(rows(mtc_1  )) + " by " + strofreal(cols(mtc_1  ))
  //DEBUG//   "dst_1   is " + strofreal(rows(dst_1  )) + " by " + strofreal(cols(dst_1  ))
  //DEBUG//   "block_1 is " + strofreal(rows(block_1)) + " by " + strofreal(cols(block_1))
  //DEBUG//   "+++ end of dtalink2::load()"
  //DEBUG// }
}

// dtalink::probabilisticlink() performs probabilistic linkage
// however all the action is in the subroutines that it calls
// this function is just a high level wrapper to loop over any blocking variables
// optionally (if em), running sums are computed for calculating newweights
void dtalink::probabilisticlink(| real scalar em)
{

  //DEBUG// if (debug) "+++ beginning of dtalink::probabilisticlink()"
  if (args()<1) em = 0

  if (num_block_vars) {
    real scalar B
    for (B=1; B<=num_block_vars; B++) {
      (void) link_one_block_var(B,em)
    }
  }
  else {
    (void) link_one_block(em)
  }

  if (em) (void) newweights()

  //DEBUG// if (debug) {
  //DEBUG//   "pairs  is " + strofreal(rows(pairs)) + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::probabilisticlink()"
  //DEBUG// }
}

// intersect() gives the intersection of two column vectors
// That is, if you type C=intersect(A,B), then the column vector C contains the elements common to A and B, sorted, with no repetitions.
// If you have two rowvectors, intersect(A',B')' will give the corresponding result, with a little loss of speed
transmorphic colvector dtalink::intersect(transmorphic colvector v_0, transmorphic colvector v_1)
{
  if (eltype(v_0)!=eltype(v_1)) _error("the 2 vectors have different eltypes")
  if (!rows(v_0) | !rows(v_1)) return(J(0,0,missingof(v_0)))
  transmorphic colvector u_0, u_1; real colvector idx; real scalar r, R
  u_0=uniqrows(v_0)
  u_1=uniqrows(v_1)
  idx=J(rows(u_0), 1, .)
  R = rows(u_0)
  for (r=1; r<=R; r++) {
    idx[r] = anyof(u_1, u_0[r])
  }
  return(select(u_0, idx))
}

// the two link_one_block_var() programs perform the probabilistic linkage for the blocking variable in column B of the blocking matrix
// again, most of the action is in the subroutines
// optionally (if em), running sums are computed for calculating newweights
// the dtalink::link_one_block_var() version handels the case of de-duping one files, with or without missing data
void dtalink::link_one_block_var(real scalar B, | real scalar em)
{
  real colvector sortindex_0
  real matrix info_0, blockrange_0
  real scalar i0, I0, dotsize
  if (args()<2) em = 0

  // re-sort the data
  //DEBUG// if (debug) "sorting on "+block_vars[B]
  sortindex_0 = order((block_0[.,B],ids_0), (1,2))
  _collate(block_0, sortindex_0)
  _collate(ids_0,   sortindex_0)
  if (mtc_num) _collate(mtc_0, sortindex_0)
  if (dst_num) _collate(dst_0, sortindex_0)

  // use panelsetup() to identify rows in each block
  // this only keeps blocks with >2 rows; if there is only 1 row in the block, there cannot be a match
  info_0 = panelsetup(block_0, B, 2)
  //DEBUG// if (debug) {
  //DEBUG//   "info_0="; info_0
  //DEBUG// }

  // drop rows with blockvar==.
  // (if two records have ".x" they are treated as being in the same block)
  info_0 = select(info_0, block_0[info_0[.,1],B]:!=.)
  I0=rows(info_0)
  if (I0==0) {
    "There are no blocks for blocking set " + strofreal(B) + " of " + strofreal(num_block_vars) + ": " + block_labs[B] + "."
    return
  }

  // setup dots
  i0=-1 ; do { i0++; dotsize=1*10^i0; } while (I0 > 400*10^i0)
  stata("_dots 0, title(Starting " + strofreal(I0) + " blocks for blocking set " + strofreal(B) + " of " + strofreal(num_block_vars) + ": " + block_labs[B] + ". Each dot is " + strofreal(dotsize) + " block" + (dotsize==1 ? "" : "s") +((dotsize>1) ?  (" (" +  strofreal(floor(I0/dotsize)) + " dots total)") : "") + ".)" )

  // link each block
  i0=1
  while (i0<=I0) {
    if (mod(i0,dotsize)==0) stata("_dots " + strofreal(i0/dotsize) + " result")
    blockrange_0 = (info_0[i0,1], 1 \ info_0[i0,2], .)
    (void) link_one_block(em, blockrange_0)
    i0++
  }
  stata("_dots")

  // to lower memory back down
  mtc_match=mtc_ijnonmiss=dst_match=dst_ijnonmiss=J(0,0,.)

}

// the dtalink2::link_one_block_var() version handels the case of linking two files, with or without missing data
void dtalink2::link_one_block_var(real scalar B, | real scalar em)
{
  real colvector sortindex_0, sortindex_1
  real matrix info_0, info_1, blockrange_0, blockrange_1
  real scalar i0, I0, i1, I1, d, dotsize
  if (args()<2) em = 0

  // re-sort the data
  //DEBUG// if (debug) "sorting on "+block_vars[B]
  sortindex_0 = order((block_0[.,B],ids_0), (1,2))
  sortindex_1 = order((block_1[.,B],ids_1), (1,2))
  _collate(block_0, sortindex_0)
  _collate(block_1, sortindex_1)
  _collate(ids_0,   sortindex_0)
  _collate(ids_1,   sortindex_1)
  if (mtc_num) {
    _collate(mtc_0, sortindex_0)
    _collate(mtc_1, sortindex_1)
  }
  if (dst_num) {
    _collate(dst_0, sortindex_0)
    _collate(dst_1, sortindex_1)
  }

  // use panelsetup() to identify rows in each block
  info_0 = panelsetup(block_0, B, 1)
  info_1 = panelsetup(block_1, B, 1)
  //DEBUG// if (debug) {
  //DEBUG//   "info_0="; info_0
  //DEBUG//   "info_1="; info_1
  //DEBUG// }

  // drop rows with blockvar==.
  // (if two records have ".x" they are treated as being in the same block)
  info_0 = select(info_0, block_0[info_0[.,1],B]:!=.)
  info_1 = select(info_1, block_1[info_1[.,1],B]:!=.)

  // setup dots
  I0 = length(intersect(block_0[info_0[.,1],B], block_1[info_1[.,1],B]))
  i0=-1 ; do { i0++; dotsize=1*10^i0; } while (I0 > 400*10^i0)
  if (I0==0) {
    "There are no blocks for blocking set " + strofreal(B) + " of " + strofreal(num_block_vars) + ": " + block_labs[B] + "."
    return
  }
  stata("_dots 0, title(Starting " + strofreal(I0) + " blocks for blocking set " + strofreal(B) + " of " + strofreal(num_block_vars) + ": " + block_labs[B] + ". Each dot is " + strofreal(dotsize) + " block" + (dotsize==1 ? "" : "s") +((dotsize>1) ?  (" (" +  strofreal(floor(I0/dotsize)) + " dots total)") : "") + ".)" )

  // link each block
  // this takes advantage of the fact that files are sorted by the blocking variable
  i0=i1=1; I0=rows(info_0); I1=rows(info_1); d=0
  while (i0<=I0 & i1<=I1) {
    if      (block_0[info_0[i0,1],B] < block_1[info_1[i1,1],B]) {
      i0++
    }
    else if (block_0[info_0[i0,1],B] > block_1[info_1[i1,1],B]) {
      i1++
    }
    else {
      d++
      if (mod(d,dotsize)==0) stata("_dots " + strofreal(d/dotsize) + " result")
      blockrange_0 = (info_0[i0,1], 1 \ info_0[i0,2], .)
      blockrange_1 = (info_1[i1,1], 1 \ info_1[i1,2], .)
      (void) link_one_block(em, blockrange_0, blockrange_1)
      i0++
      i1++
    }
  }
  stata("_dots")

  // to lower memory back down
  mtc_match=mtc_ijnonmiss=dst_match=dst_ijnonmiss=J(0,0,.)

}
// the two dtalink::link_one_block() programs are the core code -that performs the probabilistic linkage - the kernal
// The routine loops through the records, computes a probabilistic matching score for each potential match pair, and saves any pairs with scores above the "cutoff".
// It can do this for the entire dataset or just for one block.
// Matches that are found are appended to the matrix named "pairs" with their scores
// optionally (if em), running sums are computed for calculating newweights
// the dtalink::link_one_block() version handels the case of de-duping one files, with or without missing data
void dtalink::link_one_block(| real scalar em, real matrix blockrange_0)
{
  if (args()<1) em = 0
  if (args()<2) blockrange_0 = (1,.\num_0,.)
  real scalar i, j, idx_len, J
  real colvector index, score
  real matrix blockrange_j

  // if check_miss==0, the mtc_miss/dst_miss missing data flag is set once -- at the beginning of the problem
  // if check_miss==1, the mtc_miss/dst_miss missing data flag is set over and over again -- once for each block)
  // (I thought it would be to computationally intensive to check once per iteration of the loop
  if (mtc_num & check_miss) mtc_miss = hasmissing(mtc_0[|blockrange_0|])
  if (dst_num & check_miss) dst_miss = hasmissing(dst_0[|blockrange_0|])

  // loop over rows in file
  // each row is scored against remaining rows in file
  blockrange_j = blockrange_0
  J=blockrange_0[2,1]

  for (i=blockrange_0[1,1]; i<blockrange_0[2,1]; i++) {

    // we don't want to match against other rows with the same id. Therefore we want to start at row i + 1 + [number of other rows in matrix with same ID].
    j = i + 1
    while (ids_0[i]:==ids_0[j] & j<J) j++
    blockrange_j[1,1] = j

    // compute scores for exact and distance matching
    if (mtc_num & dst_num) score = ( mtc_score(mtc_0, i, mtc_0, blockrange_j)
                                   + dts_score(dst_0, i, dst_0, blockrange_j) )
    else if (mtc_num)      score =   mtc_score(mtc_0, i, mtc_0, blockrange_j)
    else                   score =   dts_score(dst_0, i, dst_0, blockrange_j)

    // get rowsnumbers (of score matrix) where score is above the minimum
    index = selectindex(score :>= cutoff)
    idx_len = length(index)

    // append results to this.scores
    if (idx_len) {
      store_pairs( ids_0[i] , (ids_0[|j\blockrange_0[2,1]|])[index] , score[index] )
    }

    // extra steps for calculating em weights
    if (em) {
      // For computing EM weights, accumulate a running sum of matches/nonmatches for each variable amoung matched pairs
      if (idx_len) {
        runsum_1_N = runsum_1_N + idx_len
        if (mtc_num) {
          if (mtc_miss) mtc_runsum_1 = mtc_runsum_1 :+ colsum(mtc_match[index,.]:*mtc_ijnonmiss[index,.])
          else          mtc_runsum_1 = mtc_runsum_1 :+ colsum(mtc_match[index,.])
        }
        if (dst_num) {
          if (dst_miss) dst_runsum_1 = dst_runsum_1 :+ colsum(dst_match[index,.]:*dst_ijnonmiss[index,.])
          else          dst_runsum_1 = dst_runsum_1 :+ colsum(dst_match[index,.])
        }
      }

      // For computing EM weights, accumulate a running sum of matches/nonmatches for each variable amoung non-matches
     index = selectindex(score :< cutoff)
     idx_len = length(index)
     if (idx_len) {
       runsum_0_N = runsum_0_N + idx_len
        if (mtc_num) {
          if (mtc_miss) mtc_runsum_0 = mtc_runsum_0 :+ colsum(mtc_match[index,.]:*mtc_ijnonmiss[index,.])
          else          mtc_runsum_0 = mtc_runsum_0 :+ colsum(mtc_match[index,.])
        }
        if (dst_num) {
          if (dst_miss) dst_runsum_0 = dst_runsum_0 :+ colsum(dst_match[index,.]:*dst_ijnonmiss[index,.])
          else          dst_runsum_0 = dst_runsum_0 :+ colsum(dst_match[index,.])
        }
     }
   }
  } // end of loop over i
}

// the dtalink2::link_one_block() version handels the case of linking two files, with or without missing data
void dtalink2::link_one_block(| real scalar em, real matrix blockrange_0, real matrix blockrange_1)
{

  if (args()<1) em = 0
  if (args()<2) blockrange_0 = (1,.\num_0,.)
  if (args()<3) blockrange_1 = (1,.\num_1,.)
  real scalar i, idx_len
  real colvector index, score

  // if check_miss==0, the mtc_miss/dst_miss missing data flag is set once -- at the beginning of the problem
  // if check_miss==1, the mtc_miss/dst_miss missing data flag is set once for each block)
  // (I thought it would be to computationally intensive to check once per iteration of the loop
  if (mtc_num & check_miss) mtc_miss = ( hasmissing(mtc_0[|blockrange_0|]) | hasmissing(mtc_1[|blockrange_1|]) )
  if (dst_num & check_miss) dst_miss = ( hasmissing(dst_0[|blockrange_0|]) | hasmissing(dst_1[|blockrange_1|]) )

  // loop over rows in left file
  // each row is scored against the right file
  for (i=blockrange_0[1,1]; i<=blockrange_0[2,1]; i++) {

    // compute scores for exact and distance matching
    if (mtc_num & dst_num) score = ( mtc_score(mtc_0, i, mtc_1, blockrange_1)
                                   + dts_score(dst_0, i, dst_1, blockrange_1) )
    else if (mtc_num)      score =   mtc_score(mtc_0, i, mtc_1, blockrange_1)
    else                   score =   dts_score(dst_0, i, dst_1, blockrange_1)

    // get rowsnumbers (of score matrix) where score is above the minimum
    index = selectindex(score :>= cutoff)
    idx_len = length(index)

    // append results to this.scores
    if (idx_len) {
      store_pairs( ids_0[i] , (ids_1[|blockrange_1|])[index], score[index] )
    }

    // extra steps for calculating em weights
    if (em) {

      // For computing EM weights, accumulate a running sum of matches/nonmatches for each variable amoung matched pairs
      if (idx_len) {
        runsum_1_N = runsum_1_N + idx_len
        if (mtc_num) {
          if (mtc_miss) mtc_runsum_1 = mtc_runsum_1 :+ colsum(mtc_match[index,.]:*mtc_ijnonmiss[index,.])
          else          mtc_runsum_1 = mtc_runsum_1 :+ colsum(mtc_match[index,.])
        }
        if (dst_num) {
          if (dst_miss) dst_runsum_1 = dst_runsum_1 :+ colsum(dst_match[index,.]:*dst_ijnonmiss[index,.])
          else          dst_runsum_1 = dst_runsum_1 :+ colsum(dst_match[index,.])
        }
      }

      // For computing EM weights, accumulate a running sum of matches/nonmatches for each variable amoung non-matches
      index = selectindex(score :< cutoff)
      idx_len = length(index)
      if (idx_len) {
        runsum_0_N = runsum_0_N + idx_len
         if (mtc_num) {
           if (mtc_miss) mtc_runsum_0 = mtc_runsum_0 :+ colsum(mtc_match[index,.]:*mtc_ijnonmiss[index,.])
         }
           else          mtc_runsum_0 = mtc_runsum_0 :+ colsum(mtc_match[index,.])
         if (dst_num) {
           if (dst_miss) dst_runsum_0 = dst_runsum_0 :+ colsum(dst_match[index,.]:*dst_ijnonmiss[index,.])
           else          dst_runsum_0 = dst_runsum_0 :+ colsum(dst_match[index,.])
         }
      }
    }
  }  // end of loop over i
}

// calculate scores with exact matching variables
// Note: Missing data contribute nothing--it is not considered a match or a non-match
// row i of mtc_0 is scored against mtc_1[|blockrange_j|]
real colvector dtalink::mtc_score(real matrix mtc_0, real scalar i,
                                  real matrix mtc_1, real matrix blockrange_j)
{

  real colvector scores
  mtc_match = (mtc_0[i,.]:==mtc_1[|blockrange_j|])
  if (mtc_miss) {
    mtc_ijnonmiss = ((mtc_0[i,.]:<.) :& (mtc_1[|blockrange_j|]:<.))
    scores = (mtc_match:*mtc_ijnonmiss) * mtc_poswgt + (!mtc_match:*mtc_ijnonmiss) * mtc_negwgt
  }
  else {
    scores = mtc_match * mtc_poswgt + !mtc_match * mtc_negwgt
  }
  return(scores)
}

// calculate scores with caliper matching variables
// Note: Missing data contribute nothing--it is not considered a match or a non-match
// row i of mtc_0 is scored against mtc_1[|blockrange_j|]
real colvector dtalink::dts_score(real matrix dst_0, real scalar i,
                                  real matrix dst_1, real matrix blockrange_j)
{
  real colvector scores
  dst_match = (abs(dst_0[i,.] :- dst_1[|blockrange_j|]):<=dst_radii)
  if (dst_miss) {
    dst_ijnonmiss = ((dst_0[i,.]:<.) :& (dst_1[|blockrange_j|]:<.))
    scores = (dst_match:*dst_ijnonmiss) * dst_poswgt + (!dst_match:*dst_ijnonmiss) * dst_negwgt
  }
  else {
    scores = dst_match * dst_poswgt + !dst_match * dst_negwgt
  }
  return(scores)
}


// dtalink::store_pairs() adds additional matched pairs to PAIRS
// The PAIRS matrix has three columns to hold the matched pair IDs (columns 1 and 2) and the sccore (column 3)
// The scalar PAIRSNUM, a running count of the number of pairs in the matrix, gets updated
void dtalink::store_pairs(scalar id_0, colvector ids_1, colvector scores)
{
  if (length(ids_1)==0) return
  if (length(ids_1)!=length(scores)) _error("ids_1 and scores have different lengths")
  real scalar K, S
  K        = length(ids_1)  // number of rows being added
  S        = pairsnum + 1  // first row with new data
  pairsnum = S + K - 1     // last  row with new data

  // if pairs is not large enough to fit the new data, it is expanded an additional K+initrows
  if (pairmatnum<pairsnum) {
    pairs = pairs \ J(initrows+K,cols(pairs),.)
    pairmatnum = rows(pairs)
  }

  // store the new data
  pairs[|S,1 \ pairsnum,1|] = J(K,1,id_0)
  pairs[|S,2 \ pairsnum,2|] = ids_1
  pairs[|S,3 \ pairsnum,3|] = scores
}

// dtalink::dedup() will clean up pairs"
// 1. use uniqrows() to remove duplicates,
// 2. removes blank rows,
// 3. remove the fourth column (if it already exists)
// 4. (optionally) deal with cases when a matched pair has multiple scores:
//     if  onlymaxscores, then keep only the maximum score for each matched pair (the default)
//     if !onlymaxscores, then keeps all scores for a matched pair
void dtalink::dedup(| real scalar onlymaxscores)
{
  //DEBUG// if (debug) "+++ beginning of dtalink::dedup()"
  if (args()<1) onlymaxscores=1

  // subset, then obtain sorted, unique values
  if (pairsnum) {
    pairs = uniqrows(pairs[|1,1 \ pairsnum,3|])
  }
  else {
    pairs = J(0,3,.)
  }
  pairsnum = pairmatnum = rows(pairs)

  // optionally, drop rows 1..(pairmatnum-1) if the IDs match the following row. always keep last row.
  if (onlymaxscores & pairmatnum>=2) {
    real colvector index
    index = selectindex((pairs[|1,1\(pairmatnum-1),1|]:!=pairs[|2,1\pairmatnum,1|]) :|
                        (pairs[|1,2\(pairmatnum-1),2|]:!=pairs[|2,2\pairmatnum,2|])
                        ) \ pairmatnum
    pairs = pairs[index,.]
  }
  pairsnum = pairmatnum = rows(pairs)

  //DEBUG// if (debug) {
  //DEBUG//   "onlymaxscores="; onlymaxscores
  //DEBUG//   "pairs  is " + strofreal(rows(pairs)) + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::dedup()"
  //DEBUG// }
}

// dtalink::dedup() will add fourth column with row numbers (which will be become _matchid in the ado file)
//   and store the current number of matches in Stata's r(N)
//   and print the number of matches to the screen.
// blank rows are removed from pairs. If a fourth column already exists, it is overwritten.
void dtalink::assign()
{
  //DEBUG// if (debug) "+++ beginning of dtalink::assign()"

  if (pairsnum) {
    pairs = (pairs[|1,1\pairsnum,3|], (1::pairsnum))
  }
  else {
    pairs = J(0,4,.)
  }
  pairmatnum = pairsnum

  st_rclear()
  st_numscalar("r(pairsnum)",pairsnum)

  if (!pairsnum) "No matches were found."
  else if (pairsnum==1) "1 match was found."
  else (strofreal(pairsnum) + " matches were found.")

  //DEBUG// if (debug) {
  //DEBUG//   "pairs  is " + strofreal(rows(pairs)) + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::assign()"
  //DEBUG// }
}

// bestmatch() deals with case where an `id' is assigned to multiple _matchIDs.
//   bestmatch() impliments the `bestmatch' option in the adofile
//     We keep each _matchIDs with the highest score, as long as the two IDs are not assigned to a "better" match.
//     Ties are broken in descending order by _score, then assending order by _id_0 and _id_1.
//  The dtalink (1-file) version does not allow arguments, since the `srcbestmatch' option is not applicable
void dtalink::bestmatch()
{
  //DEBUG// if (debug) "+++ beginning of dtalink::bestmatch()"

  if (pairsnum<=1) return
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")
  real colvector keepflag; real scalar i,j

  "Keeping best match for each " + id_var
  (void) _sort(pairs, (-3,1,2,4))    // <-- key difference between dtalink::bestmatch() and dtalink2::bestmatch()

  // this is a vector of dummies: 1 ---> keep row, 0 --> drop row
  // first row is okay because of sort and we know there are >1 rows in pairs
  keepflag = J(pairsnum,1,1)
  keepflag[1] = 1
  j = 0

  // loop through rows in pairs, updating _dropflag variable file as we go
  for (i=2; i<=pairsnum; i++) {
    j++

    // if lID has been matched before or rID has been matched before, ignore the match
    // (since the rID has been matched to a different (better) lID or lID has been matched to a different (better) rID.)
    if ( any( ((pairs[|1,1\j,1|]:==pairs[i,1]) :| (pairs[|1,2\j,2|]:==pairs[i,2])) :& (keepflag[|1 \ j|])) ) {
      keepflag[i] = 0
    }

    // Otherwise, neither ID has been matched before, so keep the match (leave keepflag = 1)

  } // end of loop over rows

  // subset the data
  "(" + strofreal(sum(!keepflag)) + " pairs deleted.)"
  pairs = select(pairs,keepflag)
  pairsnum = pairmatnum = rows(pairs)

  // now sort ascending by score
  (void) _sort(pairs, (4,1,2,3))

  //DEBUG// if (debug) {
  //DEBUG//   "pairs  is " + strofreal(rows(pairs)) + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::bestmatch()"
  //DEBUG// }
} // end of dtalink::bestmatch()

// Without arguments, this function acts the same as the dtalink (1-file) version, with modifications for the 2nd file.
//  The arguments deal with the case where an `id' in one file (0 or 1) is assigned to multiple _matchIDs.
//    After running this subroutine, each `id' in file=`srcbestmatch' will be assigned to exactly zero or one _matchID.
//    Each `id' in file=(1-`srcbestmatch') may be assigned to 2 or more _matchIDs
//    For each `id' in file=`srcbestmatch', we keep each _matchIDs with the highest score.
//    Ties are broken in descending order by _score, then assending order by _id`srcbestmatch' and _id(1-`srcbestmatch').
void dtalink2::bestmatch(| real scalar srcbestmatch)
{
  //DEBUG// if (debug) {
  //DEBUG//   "+++ beginning of dtalink2::bestmatch()"
  //DEBUG//   "args()"
  //DEBUG//    args();
  //DEBUG//   if (args()) {
  //DEBUG//     "srcbestmatch"
  //DEBUG//      srcbestmatch
  //DEBUG//   }
  //DEBUG// }

  if (pairsnum<=1) return
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")
  real colvector keepflag;

  // bestmatch appraoch -- assign each ID to exactly one _matchID
  if (args()==0) {

    "Keeping best match for each " + id_var
    (void) _sort(pairs, (-3,2,1,4))    // <-- key difference between dtalink::bestmatch() and dtalink2::bestmatch()

    // this is a vector of dummies: 1 ---> keep row, 0 --> drop row
    // first row is okay because of sort and we know there are >1 rows in pairs
    keepflag = J(pairsnum,1,1)
    keepflag[1] = 1

    // loop through rows in pairs, updating _dropflag variable file as we go
    real scalar i,j
    j = 0
    for (i=2; i<=pairsnum; i++) {

      // if lID has been matched before or rID has been matched before, ignore the match
      // (since the rID has been matched to a different (better) lID or lID has been matched to a different (better) rID.)
      j++
      if ( any( ((pairs[|1,1\j,1|]:==pairs[i,1]) :| (pairs[|1,2\j,2|]:==pairs[i,2])) :& (keepflag[|1 \ j|])) ) {
        keepflag[i] = 0
      }

      // Otherwise, neither ID has been matched before, so keep the match (leave keepflag = 1)

    } // end of loop over rows
  }

  else if (srcbestmatch==0) {
    "Keeping best match for each _id in file 0"
    (void) _sort(pairs, (1,-3,2,4))
    keepflag = (1 \ (pairs[|2,1\pairsnum,1|] :!= pairs[|1,1\(pairsnum-1),1|]))     // equivalent by _id_0: keep if _n==1   (always keep first row)
  }

  else if (srcbestmatch==1) {
    "Keeping best match for each _id in file 1"
    (void) _sort(pairs, (2,-3,1,4))
    keepflag = (1 \ (pairs[|2,2\pairsnum,2|] :!= pairs[|1,2\(pairsnum-1),2|]))     // equivalent by _id_1: keep if _n==1   (always keep first row)
  }

  else _error("Argument must be 0 or 1")

  // subset the data
  "(" + strofreal(sum(!keepflag)) + " rows deleted.)"
  pairs = select(pairs,keepflag)
  pairsnum = pairmatnum = rows(pairs)

  // now sort descending by score
  (void) _sort(pairs, (-4,1,2,3))

  //DEBUG// if (debug) {
  //DEBUG//   "keepflag       is " + strofreal(rows(keepflag)) + " by " + strofreal(cols(keepflag))
  //DEBUG//   "sum(keepflag)  is " + strofreal(rows(keepflag)) + " by " + strofreal(cols(keepflag))
  //DEBUG//   "pairs          is " + strofreal(rows(pairs))    + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink2::bestmatch()"
  //DEBUG// }
} // end of dtalink2::bestmatch()

// dropinferior() deals with case where an `id' is assigned to multiple _matchIDs.
// it is similar to  bestmatch() except in how it handles ties
//   bestmatch() impliments the `bestmatch' option in the adofile
//     We keep each _matchIDs with the highest score, as long as the two IDs are not assigned to a "better" match.
//     Ties are kept.  An `id' could assigned to multiple _matchIDs, so long as all those _matchIDs have the same score.
//  The dtalink (1-file) version does not allow arguments, since the `srcbestmatch' option is not applicable
//  Consider running combinesets() after this function.
void dtalink::dropinferior()
{
  //DEBUG// if (debug) "+++ beginning of dtalink::dropinferior()"

  if (pairsnum<=1) return
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")
  real colvector keepflag; real scalar i,j

  "Keeping best match for each " + id_var + " (keeping ties)"
  (void) _sort(pairs, (-3,1,2,4))    // <-- key difference between dtalink::dropinferior() and dtalink2::dropinferior()

  // this is a vector of dummies: 1 ---> keep row, 0 --> drop row
  // first row is okay because of sort and we know there are >1 rows in pairs
  keepflag = J(pairsnum,1,.)
  keepflag[1] = 1
  j = 0

  // loop through rows in pairs, updating _dropflag variable file as we go
  for (i=2; i<=pairsnum; i++) {
    j++

    // if lID has been matched before or rID has been matched before, ignore the match
    // (since the rID has been matched to a different (better) lID or lID has been matched to a different (better) rID.)
    if (any(((pairs[|1,1\j,1|] :== pairs[i,1]) :| (pairs[|1,2\j,2|] :== pairs[i,2])) :& (keepflag[|1 \ j|]) :& (pairs[|1,3\j,3|]:>pairs[i,3]))) {
      keepflag[i] = 0
    }

    // Otherwise, neither ID has been matched before, so keep the match (leave keepflag = 1)

  } // end of loop over rows

  // subset the data
  "(" + strofreal(sum(!keepflag)) + " pairs deleted.)"
  pairs = select(pairs,keepflag)
  pairsnum = pairmatnum = rows(pairs)

  // now sort ascending by score
  (void) _sort(pairs, (4,1,2,3))

  //DEBUG// if (debug) {
  //DEBUG//   "pairs  is " + strofreal(rows(pairs)) + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::dropinferior()"
  //DEBUG// }

} // end of dtalink::dropinferior()

// It is similar to  bestmatch() except in how it handels ties.
// Without arguments, this function acts the same as the dtalink (1-file) version, with modifications for the 2nd file.
//  The arguments deal with the case where an `id' in one file (0 or 1) is assigned to multiple _matchIDs.
//    After running this subroutine, each `id' in file=`srcbestmatch' will be assigned to exactly zero or one _matchID.
//    Each `id' in file=(1-`srcbestmatch') may be assigned to 2 or more _matchIDs
//    For each `id' in file=`srcbestmatch', we keep each _matchIDs with the highest score.
//  Ties are kept.  An `id' could assigned to multiple _matchIDs, so long as all those _matchIDs have the same score.
//  Consider running combinesets() after this function.
void dtalink2::dropinferior(| real scalar srcbestmatch)
{
  //DEBUG// if (debug) {
  //DEBUG//   "+++ beginning of dtalink2::dropinferior()"
  //DEBUG//   "args()"
  //DEBUG//    args();
  //DEBUG//   if (args()) {
  //DEBUG//     "srcbestmatch"
  //DEBUG//      srcbestmatch
  //DEBUG//   }
  //DEBUG// }

  if (pairsnum<=1) return
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")

  // this is a vector of dummies: 1 ---> keep row, 0 --> drop row
  // first row is okay because of sort and we know there are >1 rows in pairs
  real colvector keepflag; real scalar i,j
  keepflag = J(pairsnum,1,1)
  keepflag[1] = 1
  j = 0

  // dropinferior appraoch -- assign each ID to exactly one _matchID
  if (args()==0) {

    "Keeping best match for each " + id_var + " (keeping ties)"
    (void) _sort(pairs, (-3,2,1,4))    // <-- key difference between dtalink::dropinferior() and dtalink2::dropinferior()

    // loop through rows in pairs, updating _dropflag variable file as we go
    for (i=2; i<=pairsnum; i++) {

      // if lID has been matched before or rID has been matched before, ignore the match -- unless the score is a tie
      // (since the rID has been matched to a different (better) lID or lID has been matched to a different (better) rID.)
      // Otherwise, neither ID has been matched before, so keep the match  (leave keepflag = 1)
      j++
      if (any(((pairs[|1,1\j,1|] :== pairs[i,1]) :| (pairs[|1,2\j,2|] :== pairs[i,2])) :& (keepflag[|1 \ j|]) :& (pairs[|1,3\j,3|] :> pairs[i,3])))  {
        keepflag[i] = 0
      }

    } // end of loop over rows
  }

  else if (srcbestmatch==0) {
    "Keeping best match for each _id in file 0 (keeping ties)"
    (void) _sort(pairs, (1,-3,2,4))

    keepflag = (1 \ (pairs[|2,1\pairsnum,1|] :!= pairs[|1,1\(pairsnum-1),1|]))     // equivalent by _id_0: keep if _n==1   (always keep first row)

    // loop through rows in pairs, updating _dropflag variable file as we go
    for (i=2; i<=pairsnum; i++) {
      j++

      // if lID has been matched before or rID has been matched before, ignore the match -- unless the score is a tie
      // (since the rID has been matched to a different (better) lID or lID has been matched to a different (better) rID.)
      // Otherwise, neither ID has been matched before, so keep the match  (leave keepflag = 1)
      if (any((pairs[|1,1\j,1|] :== pairs[i,1]) :& (keepflag[|1 \ j|]) :& (pairs[|1,3\j,3|] :> pairs[i,3]))) {
        keepflag[i] = 0
      }
    }
  }

  else if (srcbestmatch==1) {
    // same as before, but use IDs column 2 instead of column 1
    "Keeping best match for each _id in file 1  (keeping ties)"
    (void) _sort(pairs, (2,-3,1,4))
    for (i=2; i<=pairsnum; i++) {
      j++
      if (any((pairs[|1,2\j,2|] :== pairs[i,2]) :& (keepflag[|1 \ j|]) :& (pairs[|1,3\j,3|] :> pairs[i,3]))) {
        keepflag[i] = 0
      }
    }
  }

  else _error("Argument must be 0 or 1")

  // subset the data
  "(" + strofreal(sum(!keepflag)) + " rows deleted.)"
  pairs = select(pairs,keepflag)
  pairsnum = pairmatnum = rows(pairs)

  // now sort descending by score
  (void) _sort(pairs, (-4,1,2,3))

  //DEBUG// if (debug) {
  //DEBUG//   "keepflag       is " + strofreal(rows(keepflag)) + " by " + strofreal(cols(keepflag))
  //DEBUG//   "sum(keepflag)  is " + strofreal(rows(keepflag)) + " by " + strofreal(cols(keepflag))
  //DEBUG//   "pairs          is " + strofreal(rows(pairs))    + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink2::dropinferior()"
  //DEBUG// }

} // end of dtalink2::dropinferior()

// dtalink_combinesets() is the mata routine for the subcommand dtalink_combinesets
// After running this subroutine, _matchID be updated so that each _ID includes all IDs that were ever matched together
void dtalink::combinesets()
{
  //DEBUG// if (debug) "+++ beginning of dtalink::combinesets()"
  //DEBUG// if (debug) strofreal(rows(uniqrows(pairs[.,4]))) + " groups"
  real colvector grpid_copy, find; real rowvector otherids; real scalar i, k
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")
  if (pairsnum<=1) return

  // repeat this loop until we get convergence
  k=0
  do {
    ++k
    grpid_copy = pairs[.,4]

    // loop through rows in dataset, updating group_var as we go
    for (i=2; i<=pairsnum; i++) {

      // See if lid or rid in row i was matched in rows 1 to i-1 (for de-duping, look in both columns)
      if ( anyof(pairs[|1,1\(i-1),2|],pairs[i,1]) :|
           anyof(pairs[|1,1\(i-1),2|],pairs[i,2])  ) {

        // if lid or rid in row i was matched in rows 1 to i-1, replace group ID from the first time the ID was matched in all the associated rows (including row i)
        find = selectindex( (pairs[|1,1\(i-1),1|]:==pairs[i,1]) :|
                            (pairs[|1,1\(i-1),1|]:==pairs[i,2]) :|
                            (pairs[|1,2\(i-1),2|]:==pairs[i,1]) :|
                            (pairs[|1,2\(i-1),2|]:==pairs[i,2]) ) \ i
        otherids = uniqrows(pairs[find,4])
        find = selectindex(rowsum(pairs[.,4]:==J(pairsnum,1,otherids')))
        pairs[find,4]=J(rows(find),1,otherids[1])
      }
    } // end of loop over i
  } while (grpid_copy != pairs[.,4])
  "(dtalink::combinesets required " + strofreal(--k) + (k>1 ? " iterations" : " iteration") + " to achieve convergence)"

  //DEBUG// if (debug) {
  //DEBUG//   "at end, there are " + strofreal(rows(uniqrows(pairs[.,4]))) + " groups"
  //DEBUG//   "pairs          is " + strofreal(rows(pairs))    + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::combinesets()"
  //DEBUG// }
}

// dtalink2::combinesets() is the 2-file version of dtalink::combinesets()
void dtalink2::combinesets()
{
  //DEBUG// if (debug) "+++ beginning of dtalink2::combinesets()"
  //DEBUG// if (debug) "at beginning, there are " + strofreal(rows(uniqrows(pairs[.,4]))) + " groups"
  real colvector grpid_copy, find; real rowvector otherids; real scalar i, k
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")
  if (pairsnum<=1) return

  // repeat this loop until we get convergence
  k=0
  do {
    ++k
    grpid_copy = pairs[.,4]

    // loop through rows in dataset, updating group_var as we go
    for (i=2; i<=pairsnum; i++) {

      // See if lid or rid in row i was matched in rows 1 to i-1 (for linking, we look in same column)
      if ( anyof(pairs[|1,1\(i-1),1|],pairs[i,1]) |
           anyof(pairs[|1,2\(i-1),2|],pairs[i,2]) ) {

        // if lid or rid in row i was matched in rows 1 to i-1, replace group ID from the first time the ID was matched in all the associated rows (including row i)
        find = selectindex( (pairs[|1,1\(i-1),1|]:==pairs[i,1]) :|
                            (pairs[|1,2\(i-1),2|]:==pairs[i,2]) ) \ i
        otherids = uniqrows(pairs[find,4])
        find = selectindex(rowsum(pairs[.,4]:==J(pairsnum,1,otherids')))
        pairs[find,4]=J(rows(find),1,otherids[1])
      }
    } // end of loop over i
  } while (grpid_copy != pairs[.,4])
  "(dtalink2::combinesets required " + strofreal(--k) + (k>1 ? " iterations" : " iteration") + " to achieve convergence)"

  //DEBUG// if (debug) {
  //DEBUG//   "at end, there are " + strofreal(rows(uniqrows(pairs[.,4]))) + " groups"
  //DEBUG//   "pairs          is " + strofreal(rows(pairs))    + " by " + strofreal(cols(pairs))
  //DEBUG//   "pairsnum="; pairsnum
  //DEBUG//   "pairmatnum="; pairmatnum
  //DEBUG//   "first 40 rows of pairs:"; if (pairmatnum) pairs[|1,1\min((40,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink2::combinesets()"
  //DEBUG// }
}

// dtalink::newweights() re-computes weights using number of matches amoung pairs and non-pairs pairs() and a
// resuls are saved in both macros and returned to stata in r()
// optional argument trims p1/p2 away from zero. Default is smallestdouble().
void dtalink::newweights(| real scalar trim)
{

  //DEBUG// if (debug) "+++ beginning of dtalink::newweights()"
  //DEBUG// if (debug) "pairs  is " + strofreal(rows(pairs)) + " by " + strofreal(cols(pairs))
  if (pairsnum<1) _error("No pairs available for dtalink:newweights to use")
  real colvector p1, p2, c
  string rowvector spec
  if (args()<1) trim = smallestdouble()
  spec = J(1,0,"")

  // compute weights for exact matching variables
  if (mtc_num) {
    //DEBUG// if (debug) "mtc_runsum_1  is " + strofreal(rows(mtc_runsum_1)) + " by " + strofreal(cols(mtc_runsum_1))
    //DEBUG// if (debug) "mtc_runsum_0  is " + strofreal(rows(mtc_runsum_0)) + " by " + strofreal(cols(mtc_runsum_0))

    p1 = rowmax(( (mtc_runsum_1' :/ runsum_1_N) , J(mtc_num,1,trim) ))
    p2 = rowmax(( (mtc_runsum_0' :/ runsum_0_N) , J(mtc_num,1,trim) ))
    new_mtc_poswgt = (1 / log(2)) :* (log(p1) :- log (p2))
    new_mtc_poswgt = rowmax((new_mtc_poswgt, J(mtc_num,1,0))) // don't allow negative numbers
    //DEBUG// if (debug) "new_mtc_poswgt  is " + strofreal(rows(new_mtc_poswgt)) + " by " + strofreal(cols(new_mtc_poswgt))

    p1 = rowmax(( (J(mtc_num,1,1) :- p1), J(mtc_num,1,trim)))
    p2 = rowmax(( (J(mtc_num,1,1) :- p2), J(mtc_num,1,trim)))
    new_mtc_negwgt = (1 / log(2)) :* (log(p1) :- log (p2))
    new_mtc_negwgt = rowmin((new_mtc_negwgt, J(mtc_num,1,0))) // don't allow positive numbers
    //DEBUG// if (debug) "new_mtc_negwgt  is " + strofreal(rows(new_mtc_negwgt)) + " by " + strofreal(cols(new_mtc_negwgt))

    for (c=1;c<=mtc_num;c++) {
      spec = (spec, mtc_vars[c], strofreal(new_mtc_poswgt[c]), strofreal(new_mtc_negwgt[c]))
    }
  }

  // compute weights for caliper matching variables
  if (dst_num) {
    //DEBUG// if (debug) "dst_runsum_1  is " + strofreal(rows(dst_runsum_1)) + " by " + strofreal(cols(dst_runsum_1))
    //DEBUG// if (debug) "dst_runsum_0  is " + strofreal(rows(dst_runsum_0)) + " by " + strofreal(cols(dst_runsum_0))

    p1 = rowmax(( (dst_runsum_1' :/ runsum_1_N) , J(dst_num,1,trim) ))
    p2 = rowmax(( (dst_runsum_0' :/ runsum_0_N) , J(dst_num,1,trim) ))
    new_dst_poswgt = (1 / log(2)) :* (log(p1) :- log (p2))
    //DEBUG// if (debug) "new_dst_poswgt  is " + strofreal(rows(new_dst_poswgt)) + " by " + strofreal(cols(new_dst_poswgt))

    p1 = rowmax(( (J(dst_num,1,1) :- p1), J(dst_num,1,trim)))
    p2 = rowmax(( (J(dst_num,1,1) :- p2), J(dst_num,1,trim)))
    new_dst_negwgt = (1 / log(2)) :* (log(p1) :- log (p2))
    //DEBUG// if (debug) "new_mtc_negwgt  is " + strofreal(rows(new_dst_negwgt)) + " by " + strofreal(cols(new_dst_negwgt))

    for (c=1;c<=dst_num;c++) {
      spec = (spec, dst_vars[c], strofreal(new_dst_poswgt[c]), strofreal(new_dst_negwgt[c]), strofreal(dst_radii[c]))
    }
  }

  // save to r()
  st_rclear()
  st_global("r(new_wgt_specs)", invtokens(spec))
  if (mtc_num) {
    st_matrix("r(new_mtc_poswgt)",new_mtc_poswgt)
    st_matrix("r(new_mtc_negwgt)",new_mtc_negwgt)
  }
  if (dst_num) {
    st_matrix("r(new_dst_poswgt)",new_dst_poswgt)
    st_matrix("r(new_dst_negwgt)",new_dst_negwgt)
  }
  if (mtc_num & dst_num) {
    st_matrix(         "r(new_weights)",((new_dst_poswgt , new_dst_negwgt, dst_radii')  \
                                         (new_mtc_poswgt , new_mtc_negwgt, J(mtc_num,1,.))))
    st_matrixrowstripe("r(new_weights)",((J(dst_num,1,"Caliper_matching_variables"), dst_vars') \
                                        (J(mtc_num,1,"Exact_matching_variables"  ), mtc_vars')))
    st_matrixcolstripe("r(new_weights)", ("", "new_wgt_match" \ "", "new_wgt_no_match" \ "", "Caliper" ))
  }
  else if (mtc_num) {
    st_matrix(         "r(new_weights)", (new_mtc_poswgt , new_mtc_negwgt))
    st_matrixrowstripe("r(new_weights)", (J(mtc_num,1,"Exact_matching_variables"), mtc_vars'))
    st_matrixcolstripe("r(new_weights)", ("", "new_wgt_match" \ "", "new_wgt_no_match" ))
  }
  else if (dst_num) {
    st_matrix(         "r(new_weights)", (new_dst_poswgt , new_dst_negwgt, dst_radii'))
    st_matrixrowstripe("r(new_weights)", (J(dst_num,1,"Caliper_matching_variables"), dst_vars'))
    st_matrixcolstripe("r(new_weights)", ("", "new_wgt_match" \ "", "new_wgt_no_match" \ "", "Caliper" ))
  }

  //DEBUG// if (debug) "+++ end of dtalink::new_wgt_ights()"
}

// dtalink::extract() moves the results from mata back to Stata
// user needs to provider a list of 3 or 4 variables
// the left ID, the right ID, the score, and (optionallY) a match ID
void dtalink::extract(string rowvector varnames)
{
  //DEBUG// if (debug) "+++ beginning of dtalink::extract()"

  string rowvector vars
  vars = tokens(varnames)
  if (length(vars)<3) _error("Too few variable names provided.")
  if (length(vars)>cols(pairs)) _error("Too many variable names provided.")

  // write data in rows 1 to pairsnum of variables in varnames
  // don't write anything if there are 0 pairs
  if (pairsnum) {
    st_updata(1)
    if ( c("N") < pairsnum ) st_addobs(pairsnum-c("N"), 1)
    else if ( c("N") > pairsnum ) st_store((pairsnum+1, c("N")), vars, J(c("N")-pairsnum,length(vars),.))
    st_store((1, pairsnum), vars, pairs[|1,1\.,length(vars)|])
  }

  st_rclear()
  st_numscalar("r(pairsnum)",pairsnum)

  //DEBUG// if (debug) stata("codebook, compact")
  //DEBUG// if (debug) "+++ end of dtalink::extract()"
}

// dtalink::tall() returns the PAIRS matrix in a "tall," rather than "wide," format
// a matrix is returned; first column has IDs, second column has scores, third column has match ID,
// and fourth colummn is 0 for left ID and 1 for right ID
// (when linking 2 files, the values in this last colulmn correspond to file 0 and file 1)
real matrix dtalink::tall()
{
  //DEBUG// if (debug) "+++ beginning of dtalink::tall()"
  real matrix out
  if (!pairsnum) return(J(0,4,.))
  if (cols(pairs)<4) _error("match IDs have not been assigned; call dtalink::assign()")

  out = pairs[|1,1\pairsnum,1|] , pairs[|1,3\pairsnum,4|] , J(pairsnum,1,0) , (1::pairsnum) \
        pairs[|1,2\pairsnum,2|] , pairs[|1,3\pairsnum,4|] , J(pairsnum,1,1) , (1::pairsnum)
  (void) _sort(out,(5,4))
  out = out[|1,1\.,4|]

  //DEBUG// if (debug) {
  //DEBUG//   "first 5 rows of pairs:";      if (pairsnum) pairs[|1,1\min((5,rows(pairs))),.|];
  //DEBUG//   "first 10 rows of tall file:"; if (pairsnum)   out[|1,1\min((10,rows(pairs))),.|];
  //DEBUG//   "+++ end of dtalink::tall()"
  //DEBUG// }
  return(out)
}

end
