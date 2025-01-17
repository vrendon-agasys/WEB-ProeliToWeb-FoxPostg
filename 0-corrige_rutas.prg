CLOSE ALL

USE direc 
UPDATE direc SET k_nomb = "\\fonellip\f\ndatos\"  where k_nomb = "F:\DATELI\"
UPDATE direc SET k_nomb = "\\fonellip\f\ndatos1\" where k_nomb = "F:\DUTELI\"

SELECT direc
BROWSE last

USE IN direc

USE c:\dev\proeli\web\configfoxmysql
GO top
replace server     WITH "localhost"
replace pathproeli WITH "c:\dev\proeli\"
replace pathdirsdo WITH "\\fonellip\f\ndatos\"
replace pathtexto  WITH "c:\dev\proeli\texto\"
EDIT

USE IN configfoxmysql

RETURN
