SELECT * FROM table(DBMS_XPLAN.DISPLAY_CURSOR('&1', null,'ALL ALLSTATS LAST'))
/
