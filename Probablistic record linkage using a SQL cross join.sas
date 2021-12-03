* Example of performing probablistic record linkage with a SQL cross join
* by Keith Kranker
* November 30, 2021;

********************************************
Create two fake datasets, each with five
matching variables (x1, x2, x3, x4, x5)
********************************************;

data A;
  call streaminit(1);
  length id x1 x2 x3 8; length x4 x5 $3;
  do id = 1 to 100; /* record id needs to be unique in each file */
     x1 = id + 80;
     x2 = rand("TABLE", 0.4) - 1;
     x3 = 25+floor(10*rand("UNIFORM"));
     x4 = byte(int(65+10*rand("UNIFORM")));
     x5 = byte(int(65+26*rand("UNIFORM")));
     output;
  end;
run;
proc print data=A(obs=10);
  title 'Example records in file A';
run;

data B;
  call streaminit(2);
  length id x1 x2 x3 8; length x4 x5 $3;
  do id = 1 to 250; /* record id needs to be unique in each file */
     x1 = id + 120;
     x2 = rand("TABLE",0.6) - 1;
     x3 = 25+floor(10*rand("UNIFORM"));
     x4 = byte(int(65+11*rand("UNIFORM")));
     x5 = byte(int(65+26*rand("UNIFORM")));
     output;
  end;
run;
proc print data=B(obs=10);
  title 'Example records in file B';
run;



*******************
Set up the linkage
*******************;

* poswgt# is added to the score if two observations match on variable x#;
%LET poswgt1a =  0.5;  /* Note, we have two sets of weights for variable x1.*/
%LET poswgt1b =  9.0;  /* The dtalink documentation explains why we do that.*/
%LET poswgt2  =  0.2;
%LET poswgt3  =  5.0;
%LET poswgt4  =  0.4;
%LET poswgt5  =  5.5;

* negwgt# is added to the score if two observations do not match on variable x#;
%LET negwgt1a =    0;
%LET negwgt1b = -2.0;
%LET negwgt2  = -0.5;
%LET negwgt3  = -0.2;
%LET negwgt4  = -0.8;
%LET negwgt5  = -1.5;

* variable x# is considered a "match" if the two observatiosn are within radius#;
%LET radius1b = 5;
%LET radius3  = 2;

* autmatically accept linkages with scores above 10;
%LET accept_cutoff = 10;

* review linkage with scores above 9 (but below 10);
%LET review_cutoff = 9;


********************
Perform the linkage
********************;

proc sql;
  title 'View S peforms the cross join and computes probabilistic linking scores';
  create view S as
    select A.id as id_A,
           B.id as id_B,
           0 + ifn(A.x1 EQ B.x1                  , &poswgt1a., &negwgt1a.)
             + ifn(abs(A.x1 - B.x1) <= &radius1b., &poswgt1b., &negwgt1b.)
             + ifn(A.x2 EQ B.x2                  , &poswgt2. , &negwgt2. )
             + ifn(abs(A.x3 - B.x3) <= &radius3. , &poswgt3. , &negwgt3. )
             + ifn(A.x4 EQ B.x4                  , &poswgt4. , &negwgt4. )
             + ifn(A.x5 EQ B.x5                  , &poswgt5. , &negwgt5. ) as score
    from A cross join B;

  title 'Table Lw runs view S, keeping linkages with score > &review_cutoff.';
  create table Lw as
    select monotonic() as id_L label='unique ID for each linked dyad',
           *,
           case
             when (score < &accept_cutoff.)
             then "Review"
             else "Accept"
           end as link_status
      from S
      where score >= &review_cutoff.
      order by id_L;

  title 'Examples of linked records in file Lw';
  select * from Lw(obs = 20);
run;

* Note: At this point, one record in file A might be linked to two different
        records in file B, and vice-versa. I have a method to deal with this
        in the dtalink Stata package. Those methods could be easily replicated
        in SAS or you can come up with different rules as needed.;

* Note: Probabilistic record de-duplication essentially amounts to linking
        one file with itself. However, there is an extra step that prevents a
        particular record from being linked to itself.;


*********************
* Review the linkage
*********************;

proc tabulate data = Lw;
  title 'Review the number of linkages and the distribution of scores in Lw';
  class link_status;
  var id_L score;
  table link_status all, score * (N min mean p50 max);
run;

proc sql;
  title 'File Lt is equivalent to Lw, only it is reshaped from wide to tall';
  create table Lt as
    select 'A' as file, * from Lw(rename=(id_A=id) drop=id_B)
    outer union corr
    select 'B' as file, * from Lw(rename=(id_B=id) drop=id_A)
    order by id_L, file;

  title 'Examples of linked records in file Lt';
  select * from Lt(obs = 10);

  title 'View AB stacks files A and B for the next step';
  create view AB as
    select 'A' as file, * from A
    outer union corr
    select 'B' as file, * from B;

  title 'Review cases with scores between &review_cutoff. and &accept_cutoff.';
  create view printout as
    select *
    from Lt
  left join AB
    on Lt.id = AB.id & Lt.file = AB.file
    where link_status EQ "Review"
    order by -score, id_L, file;
  select * from printout;
run;
