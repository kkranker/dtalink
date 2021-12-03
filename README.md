# dtalink: Stata package to implement probabilistic record linkage

dtalink implements probabilistic record linkage (a.k.a. probabilistic matching) in Stata for two cases:
- deduplicating records in one data file
- linking records in two data files

[These presentation slides](https://github.com/kkranker/dtalink/raw/master/dtalink_slides.pdf)
provide an introduction to the methods and an overview of the package.


# Installation

To install from Github, type this into your Stata command line:

```stata
. net from https://raw.githubusercontent.com/kkranker/dtalink/master/
```

To install from SSC, click on the links after typing this into your Stata command line:

```stata
. net describe dtalink
```

# Suggested Citation

* Keith Kranker. "DTALINK: Stata module to implement probabilistic record linkage," Statistical Software Components S458504, Boston College Department of Economics, 2018.  Available at https://ideas.repec.org/c/boc/bocode/s458504.html.  ([slides](https://github.com/kkranker/dtalink/raw/master/dtalink_slides.pdf))

or

* Kranker, Keith. DTALINK: Faster Probabilistic Record Linking and Deduplication Methods in Stata for Large Data Files.”  ed at the 2018 Stata Conference, Columbus, OH, July 20, 2018.

Source code is available at https://github.com/kkranker/dtalink.
Please report issues at https://github.com/kkranker/dtalink/issues.


# Description

Stata users often need to link records from two or more data files or find duplicates within data files.
Probabilistic linking methods are often used when the file(s) do not have reliable or unique identifiers,
causing deterministic linking methods (such as Stata's `merge`, `joinby`, or `duplicates` commands) to fail.
For example, one might need to link files that only include
inconsistently spelled names, dates of birth with typos or missing data, and addresses that change over time.
Probabilistic linking methods score each potential pair of records using the matching variables and weights
(Newcombe et al. 1959; Fellegi and Sunter 1969).
Pairs with higher overall scores indicate a better match than pairs with lower scores.

`dtalink` implements probabilistic linking methods (a.k.a. probabilistic matching) for two cases:
l. linking records in two data files
l. deduplicating records in one data file

There are two ways to implement data linking (case 1):
(a) the user stacks the two data sets before running `dtalink` and provides a dummy to indicate the file in the `source(varname)` option, or
(b) the user provides the name of the second file with [using *filename*], in which case the master data set is assigned `source`=0 and the *using* data set is assigned `source`=1.
If neither of these are specified, data deduplication (case 2) is implemented.

The user specifies matching variables and matching weights.
For each matching variable, users can use one of two methods to compare two records for a potential match:
(a) Exact matching awards positive weights
if `(X for observation 1)` equals `(X for observation 2)`,
awards negative weights if the observations are not equal,
and awards no weights if one of the observations is missing.
(b) Caliper matching awards positive weights if
`(X for observation 1)-(X for observation 2)` is less than or equal to the *caliper* for `X`,
awards negative weights if the difference is greater than the *caliper*,
and awards no weights if `X` is missing for either of the observations.

`dtalink` offers streamlined probabilistic linking methods.
The computationally heavy parts of the program are implemented in a Mata class with parallelized Mata code,
making it practical to implement the methods with large, administrative data files
(files with many rows or matching variables). It is a generic function which works with any data file.
Flexible scoring and many-to-many matching techniques are also options.

The Stata help file ([dtalink.sthlp](https://github.com/kkranker/dtalink/raw/master/dtalink.sthlp)) provides additional documentation and examples. After installation, type
`. help dtalink` to read the package [documentation](https://github.com/kkranker/dtalink/raw/master/dtalink.sthlp).

Notes about other langauges:
l. I would love to try porting this module to [Julia](https://julialang.org/). Let me know if you can help!
l. I was asked how to do this in SQL or SAS. [This branch](https://github.com/kkranker/dtalink/tree/sql) has a toy example.
