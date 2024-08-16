***************************************************************
* fox2MySQL.PRG
* -------------------------------------------------------------
* dRendon - creacion 13/ago/2018
*
* Controla carga de archivos usados por ProEli a base de datos
* remota.
* IMPORTANTE: El programa se debe ejecutar desde el directorio
* donde estan los diccionarios de ProEli (DIREC)
* -------------------------------------------------------------

CLOSE ALL
RELEASE ALL
CLEAR ALL
CLEAR

_modoExec	= [MANUAL]		&& 'MANUAL' -> muestra mensajes | 'AUTO' -> no muestra mensajes
* _modoExec	= [AUTO]
 _continuar	= .T.

*****
* Crea instancia de la clase de control Class Master <- en este fuente
 oMaster = NEWOBJECT('master')

*****
* Crea instancia de la clase para gestionar los procesos de 
* conexion, creacion y actualizacion de tablas		
 oDB = NEWOBJECT([dbf2MySQL], [dbf2MySQL_lib.prg])
*oDB.Test()
 IF VARTYPE( oDB ) <> "O"
	_mensaje = "Error instanciando objeto..."
	IF _modoExec = [MANUAL]
		MESSAGEBOX(_mensaje,16,[ERROR])
	ELSE
		INSERT INTO bitacora (evento,descripc,fregistro) VALUES ;
		("ERROR",_mensaje,DATETIME())
	ENDIF 
	QUIT
 ENDIF
 oDB.modoExec = upper( _modoExec )

 USE (oDB.PathDIRSDO+[dirsdo]) SHARED IN 0 ORDER 1 NOUPDATE
 IF NOT USED([dirsdo])
 	_continuar = .F.
	_mensaje=[Error abriendo tabla DIRSDO]
 	IF _modoExec = [MANUAL]
 		MESSAGEBOX(_mensaje,16,[ERROR DBF])
 	ELSE 
 		oDB.UpdLog([ERROR],_mensaje)
 	ENDIF 	

	* Sin acceso a las tablas locales no es posible ejecutar
	* el proceso de copiado
	QUIT
 ENDIF 

 *****
 * Proceso para actualizar tablas remotas a partir de tablas DBF
 *****
 LOCAL _clteInic, _filInic, _clteFinal, _filFinal
 
 IF oDB.modoExec = "MANUAL"

	DO FORM formFox2MySQL

	oDB.Unload()
	clear events
	close all
	release ALL extend
	RETURN
 ENDIF

*************************************************
* Proceso batch para actualizacion de archivos	*
*************************************************

IF NOT oDB.conectar()	
	oDB.Unload()
	QUIT
ENDIF 

*					 ***
*					 * Catalogo de Agentes - todos los registros			VAR030
*					 ***
*					 oMaster.updTablaMatriz('var030')
*					 use in tmpDBF

 ***
 * Catalogo de Clientes - todos los registros.			CLI010
 ***
 _numInic	= SPACE(6)
 _filInic	= SPACE(3)
 _numFinal	= [zzzzzz]
 _filFinal	= [zzz]
 _where		=	[WHERE cc_num+cc_fil>=']+ _numInic  + _filInic + [' ] + ;
				[  AND cc_num+cc_fil<=']+ _numFinal + _filFinal +[' ]
 _order		= [CC_NUM,CC_FIL]

* Copia datos excepto campos Memo		
IF oMaster.updTablaMatriz('cli010', _where, _order) = .T.
	* Ahora actualiza tambien los campos Memo de esta tabla
	_where = [WHERE TRIM(CC_NUM) = ?alltrim(cc_num) AND TRIM(CC_FIL) = ?trim(cc_fil)]
	oDB.CopyDbf2Memo('cli010', _where)
	use in tmpDBF 
ENDIF
 
 ***
 * Expediente del cliente
 ***
 _where	=	[WHERE ex_num>=']+ _numInic + [' AND ex_fil>=']+ _filInic  +[' ] + ;
			[  AND ex_num<=']+ _numFinal+ [' AND ex_fil<=']+ _filFinal +[' ]
 _order	=	[EX_NUM,EX_FIL]

 * Copia datos excepto campos Memo
 IF oMaster.updTablaMatriz('cli015', _where, _order) = .T.
	 * Ahora actualiza campos Memo
	 _where = [WHERE TRIM(ex_num) = ?alltrim(ex_num) AND TRIM(ex_fil) = ?ALLTRIM(ex_fil) ]+;
 				[AND EX_FECHA = ?DTOS(ex_fecha) AND EX_HORA = ?ex_hora ]
	 oDB.CopyDbf2Memo('cli015', _where)
	 USE IN tmpDBF
 ENDIF

 ***
 * Catalgo de Articulos PT
 ***
 _where = ""
 _order = "C_LIN,C_CLAVE"
 IF oMaster.updTablaMatriz('inv010', _where, _order) = .T.
	USE IN tmpDBF
 ENDIF
 
 *****
 * Termina rutina
 IF oDB.ModoExec = "AUTO"
	* En modo automatico, teniamos la conexion abierta
	oDB.desconectar()
 ENDIF
 clear events
 close all
 release ALL extend

 RETURN 

 ****************************************************************************
 DEFINE CLASS Master as Custom
 ****************************************************************************
 
*********
	PROCEDURE PrintMensaje
		MESSAGEBOX([Clase TEST metodo PrintMensaje])
	ENDPROC

*********
*	Controla la actualizacion de datos de una tabla DBF que reside en
*	el directorio DATELI (oficina matriz), a la tabla correspondiente
*	en el servidor remoto.
*
*	Parametros	
*	pTabla	= identificador de la tabla, la cual debe existir en el 
*		servidor remoto y tener la misma estructura que la tabla DBF
*	pWhere	= clausula WHERE que se aplica para obtener los registros
*		que se van a copiar
*	pOrder	= Orden que debe tener la tabla para copiar sus registros
*	------------------------------------------------------------------
	PROCEDURE updTablaMatriz
		parameters pTabla, pWhere, pOrder
		local _retorno
		_retorno = .T.

		IF pcount()>1
			_where = pWhere
		ELSE
			_where = ''
		ENDIF
		IF PCOUNT()>2
			_order = pOrder
		ELSE
			_order = ''
		ENDIF 

		oDB.Tabla = pTabla
		SELECT * FROM direc WHERE k_var = "A"+UPPER(pTabla) INTO CURSOR miCursor
		IF reccount("miCursor")<1
			_mensaje = "Tabla "+pTabla+" no localizada en DIREC.DBF"
			IF _modoExec = 'MANUAL'
				WAIT WINDOW _mensaje AT 10,10 TIMEOUT 2 
			ELSE
				oDB.UpdLog("ERROR",_mensaje)
			ENDIF
			RETURN .F.
		ENDIF
		SELECT miCursor
		GO top
		USE (ALLTRIM(miCursor.k_nomb)+alltrim(miCursor.k_files)) SHARED IN 0
		USE IN miCursor

		IF USED(oDB.tabla)
			_command = [SELECT * FROM ] + oDB.tabla + [ ]
			IF LEN( _where )>0
				_command = _command + _WHERE
			ENDIF 
			IF LEN( _order )>0
				_command = _command + [ ORDER BY ] + _order
			ENDIF 
			_command = _command + [ INTO CURSOR tmpDBF]

			*****
			* Ejecuta instruccion SQL y crea cursor que se va a procesar
			 oDB.UpdLog("INFO", _command)
			 &_command
			 oDB.UpdLog("OK","Cursor creado")
			
			*****
			* Genera archivo de texto con datos que van a ser actualizados
			*****
			oDB.UpdLog("INFO","Generando archivo de texo...")
			IF oDB.CopyDbf2Texto()
				_mensaje = [Tabla ]+ oDB.Tabla +[ copiada a texto... ok]
				IF _modoExec = 'MANUAL'
					WAIT WINDOW _mensaje AT 10,10 TIMEOUT 2 
				ELSE
					oDB.UpdLog([OK],_mensaje)
				ENDIF
			ELSE 	
				_retorno = .F.
				IF _modoExec = [MANUAL]
					_mensaje=[UPD ]+ oDB.Tabla +[-> Error copiando ]+oDB.Tabla+[ a texto...]
					MESSAGEBOX(_mensaje,16,[ERROR DBF])
				ELSE 
					oDB.UpdLog([ERROR],_mensaje)
				ENDIF 		
			ENDIF
			
			USE IN (oDB.tabla)
		ELSE 
			_retorno = .F.
			_mensaje=[Copiando: ] + oDB.Tabla +[-> No pudo abrirse la tabla ]+ oDB.Tabla
			IF _modoExec = [MANUAL]
				MESSAGEBOX(_mensaje,16,[ERROR DBF])
			ELSE 
				oDB.UpdLog([ERROR],_mensaje)
			ENDIF 	
			RETURN .F.
		ENDIF  

		*****
		*	Copia datos a tabla remota
		oDB.UpdLog("INFO","Cargando archivo de texto a tabla remota...")
		IF oDB.CopyTexto2Sql()
			_mensaje = [Tabla ]+ oDB.Tabla +[ actualizada en servidor remoto... ok]
			IF _modoExec = 'MANUAL'
				WAIT WINDOW _mensaje AT 10,10 TIMEOUT 2 
			ELSE
				oDB.UpdLog([OK],_mensaje)
			ENDIF
		ELSE 
			_retorno =.F.
			_mensaje = oDB.Tabla +[-> Error copiando ]+oDB.Tabla+[ en servidor remoto...]
			IF _modoExec = [MANUAL]
				MESSAGEBOX(_mensaje,16,[ERROR DBF])
			ELSE 
				oDB.UpdLog([ERROR],_mensaje)
			ENDIF 		
		ENDIF
		
		***
		*USE IN tmpDBF	El cursor se deja abierto porque se puede utilizar 
		*				nuevamente, para copiar campos Memo
		***

		RETURN _retorno
	ENDPROC

