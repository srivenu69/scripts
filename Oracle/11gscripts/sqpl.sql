SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR('&1', null,'ADVANCED ALLSTATS LAST'))
/