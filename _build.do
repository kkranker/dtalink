*! _build.do
*  Prep files for release

version 15.1
translator set smcl2txt linesize 120

translate "C:\Users\kkranker\OneDrive - Mathematica\Documents\Stata\dtalink\code-dtalink\dtalink.sthlp"  ///
          "C:\Users\kkranker\OneDrive - Mathematica\Documents\Stata\dtalink\code-dtalink\dtalink.sthlp.txt"   ///
          , replace translator(smcl2txt)
