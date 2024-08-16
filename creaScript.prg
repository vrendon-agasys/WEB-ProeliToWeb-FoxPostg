***********************************************************
* creaScript.PRG
* A partir de una estructura DBF genera el script para crear
* la tabla en el servidor remoto MySQL
*
* Recibe el nombre de la tabla origen
PARAMETERS pTabla, pKeyName, pKeyLlave

IF PCOUNT() > 1
	_KeyName = pKeyName
	_KeyLlave = pKeyLlave
ELSE
	_KeyName = ""
	_KeyLlave = ""
ENDIF

_modoauto	= .F.	&& indica si el programa corre en modo automatico o interactivo 
_rutaDateli = [c:\@i\dateli\]
_rutaScript = [c:\dev\foxmysql\scripts\]
_continuar	= .T.
_saveEscape	= SET([ESCAPE])

SET ESCAPE ON
ON ESCAPE STORE .F. TO _continuar

USE (_rutaDateli + pTabla) SHARED NOUPDATE 
SELECT (pTabla)
_nFlds = AFIELDS(aCampos)

IF _nFlds<1
	IF _modoauto = .F.
		MESSAGEBOX(	[No se pudo obtener la estructura]+CHR(13)+;
					[de la tabla ]+pTabla, 0+16+0, [Error en datos])
	ENDIF
	MESSAGEBOX([PENDTE: escrbir en bitacora...])
	
	RETURN .F.
ENDIF

SET CONSOLE OFF
SET ALTERNATE TO (_rutaScript+pTabla+[.sql])
SET ALTERNATE ON

?  [create table ]+ pTabla + [ (]
FOR i=1 TO _nFlds
	? aCampos(i,1)+[ ]
	_fldTipo = aCampos(i,2)
	DO case
	CASE INLIST(_fldTipo, [C])
		?? [char(] + STR(aCampos[i,3],3) + [),]
	CASE INLIST(_fldTipo, [I])
		?? [INT(] + STR(aCampos[i,3],3) + [),]
	CASE INLIST(_fldTipo, [Y],[F],[N],[B])
		?? [decimal(] + STR(aCampos[i,3],3) + [),]
	CASE INLIST(_fldTipo, [L])
		?? [bit,]
	CASE INLIST(_fldTipo, [M])
		?? [text,]
	CASE INLIST(_fldTipo, [D],[T])
		?? [datetime,]
	OTHERWISE
		?? [char(20),]	
	ENDCASE 

ENDFOR 
? [logUpDate TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP]

IF LEN( _KeyName )>0
	?? [,]
	?  [KEY ]+ pKeyName + [ (]+ pKeyLlave+ [)]
ENDIF 
?? [) ]
?  [ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci ;]

SET ALTERNATE TO 
SET ALTERNATE OFF 
SET CONSOLE ON 

MODIFY COMMAND (_rutaScript+pTabla+[.sql])

ON ESCAPE
SET ESCAPE &_saveEscape
USE IN (pTabla)
RETURN .T.