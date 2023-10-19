# dtalink: Stata package to implement probabilistic record linkage

by Keith Kranker

# SQL and SAS example

I was asked how to perform probabilistic record linkage using SQL or SAS.
One option is to use a SQL cross join, like in this toy example.

## Caveats

- I didn’t provide a lot of notes, so you might want to start with the ```dtalink``` [documentation](https://github.com/kkranker/dtalink/blob/master/dtalink.sthlp.txt) and [slides](https://github.com/kkranker/dtalink/raw/master/dtalink_slides.pdf) for context. 
- I have no idea if this will be memory efficient if you were to try it with large datasets. If it does use too much memory, 
  - There might be a way to better optimize the SQL code. I did it in two discrete two steps (S and L), but that was only for the sake of clarity. It could be done in one step.
  -	 Blocking could make the problem more tractable, especially if you can find a way to process multiple blocks in "parallel."
-	There was a question about how to calculate weights using a ‘training’ dataset or an E-M routine. That can be done by computing summary statistics on the S dataset in the code; it’s not hard to add, but can be computationally intensive (because it needs all the rows in S, rather than a small subset of them). 
