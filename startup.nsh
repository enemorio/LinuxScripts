@echo -off
mode 80 25
;foundimage section is simply to locate the correct drive
cls

if exist fs0:\apache.py then
 fs0:
 echo Found ApachePass python script in fs0:
 python apache.py
endif

if exist fs1:\apache.py then
 fs1:
 echo Found ApachePass python script in fs1:
 python apache.py
endif

if exist fs2:\apache.py then
 fs2:
 echo Found ApachePass python script in fs2:
 python apache.py
endif

if exist fs3:\apache.py then
 fs3:
 echo Found ApachePass python script in fs3:
 python apache.py
endif
