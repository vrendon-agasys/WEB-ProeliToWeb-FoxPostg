*********************************************************************
* dbf2MySQL_lib.prg
* -------------------------------------------------------------------
* Clase para Gestionar la creacion de tablas en el servidor remoto
* y la copia de datos a partir de tablas DBF, utilizando como metodo
* la carga de archivos de texto.

*	Test				Pruebas al desarrollar el programa
*	Init				Llama rutinas para establecer entorno de trabajo y abre bitacora
*	Unload				Cierra tablas y limpia entorno
*	setEntorno			Define settings de entorno globales
*	clearEntorno		Limpia entorno, cierra tablas, etc.
*	configConexion		Configura conexion al servidor remoto leyendo el archivo de configuracion CONFIG.DBF
*	conectar			Se conecta al servidor de bases de datos remoto.
*	desconectar			Se desconecta del servidor remoto
*	scriptCrearBD		Genera script SQL para crear base de datos en servidor remoto.
*	scriptCrearTabla	Genera script SQL para crear tabla en servidor remoto, a partir de la estructura de una tabla DBF.
*	copyDbf2Texto		Copia datos de una tabla DBF a un archivo de texto.
*	copyTexto2Sql		Controla carga de archivo de texto a tabla remota.
*	copyDbf2Memo		Copia campos memo de una tabla DBF a una tabla MySQL. 
*	updLog				Actualiza eventos y errores en bitacora
*	textoPlano			Reemplaza caracteres no aceptados por la base de datos remota

DEFINE CLASS dbf2MySQL AS Custom

	*modoExec = MANUAL	-> interactua con el usuario
	*modoExec = AUTO	-> ejecuta en modo automatico, sin presentar mensajes
	*					   o pedir informacion
	modoExec 	= [MANUAL]	
	pathDIRSDO	= []		&& Ruta de acceso a tabla DIRSDO de Proeli
	pathProEli	= []		&& Ruta de acceso programa ProELI
	pathTexto	= []		&& Ruta donde se depositan los archivos de texto con data a copiar
	tabla 		= []		&& Tabla DBF que se va a procesar

	handle 			= 0			&& controlador asignado a la conexion remota
	handle_engine	= []		&& MySQL,MariaDB,SQLServer,...
	handle_driver	= []		&& ODBC name
	handle_server	= []		&& IP del servidor remoto o nombre del mismo
	handle_puerto	= []		&& Puerto abierto para conexion a servidor remoto
	handle_database	= []		&& Base de datos por omision
	handle_usuario	= []		&& Usuario que se conecta a la BD remota
	handle_passw	= []		&& Password del usuario que se conecta a la BD remota

	PROCEDURE Test
		MESSAGEBOX([Libreria cargada...])
	ENDPROC

	PROCEDURE Init
		CLEAR
		CLOSE ALL		
		this.SetEntorno()

		local _continuar, _mensaje

		IF FILE("BITACORA.DBF")
			USE bitacora IN 0 SHARED 
		ELSE
			CREATE TABLE bitacora (evento c(20),descripc c(80),fregistro T)
			this.UpdLog("AVISO","Fue necesario crear la tabla BITACORA...")
		ENDIF

		* Define Rutas de acceso globales
		USE config SHARED NOUPDATE 
		IF NOT USED([config])
			_mensaje = [Error al abrir archivo de configuracion]
			IF this.modoExec = [MANUAL]
				MESSAGEBOX(_mensaje,16,[ERROR])
			ELSE
				this.UpdLog([ERROR],_mensaje)
			ENDIF 
			RETURN .F.
		ENDIF 
		this.pathProEli = alltrim( config.pathproeli )
		this.pathTexto  = alltrim( config.pathTexto  )
	
		*****
		* Diccionarios de Proeli donde estan las rutas de acceso
		* a las tablas locales DBF
		 USE (this.pathProEli+"direc") SHARED NOUPDATE ORDER 1
		 IF NOT USED([direc])
 			_continuar = .F.
			_mensaje=[Error abriendo tabla ]+this.pathProEli+[DIREC.DBF]
 			IF this.modoExec = [MANUAL]
 				MESSAGEBOX(_mensaje,16,[ERROR DBF])
 			ELSE 
 				this.UpdLog([ERROR],_mensaje)
 			ENDIF 	

			* Sin acceso a las tablas locales no es posible ejecutar
			* el proceso de copiado
			RETURN .F.
		 ENDIF 
		 SELECT k_nomb,k_files,k_var FROM direc ;
		  WHERE k_var=padr("ADIRSDO",10) INTO CURSOR miCursor

		 IF RECCOUNT("miCursor")<1
			_mensaje=[No pudo establecerse la ruta de acceso a DIRSDO.DBF]
 			IF this.modoExec = [MANUAL]
 				MESSAGEBOX(_mensaje,16,[ERROR DBF])
 			ELSE 
 				this.UpdLog([ERROR],_mensaje)
 			ENDIF 	

			* Sin acceso a las tablas locales no es posible ejecutar
			* el proceso de copiado
			RETURN .F.
		 ENDIF
		 GO TOP IN miCursor
		 this.pathDIRSDO = alltrim(miCursor.k_nomb)
		 USE IN miCursor

		*****
		* Configura conexion a la base de datos a partir de CONFIG.DBF
		  this.configConexion()

	ENDPROC 
	
	PROCEDURE Unload
		this.clearEntorno()
		CLOSE ALL
		RELEASE ALL
		RELEASE ALL EXTEND
	ENDPROC
	
	PROCEDURE setEntorno
		* Define settings de entorno globales
		SET TALK OFF
		*	La teoria de Rushmore aconseja trabajar con DELETE en OFF,
		*	pero en realidad las busqueda no son significativamente mas
		*	rapidas, y como es mas comodo el switch ON, lo dejo asi.
		set deleted on
		set century on
		set date british
		set status bar on
		set compatible off
		*set bell off
		*set message to
		set safety off
		set exact off
		set cpdialog off
		SET STRICTDATE TO 0
		set exclusive off
		set multilocks on
		set reprocess to 1
		set lock off
	ENDPROC
	
	PROCEDURE clearEntorno		
		* Limpia entorno, cierra tablas, etc.
	ENDPROC

	* Configura conexion al servidor remoto	
	PROCEDURE configConexion		
		USE config SHARED NOUPDATE 
		IF NOT USED([config])
			_mensaje = [Error al abrir archivo de configuracion]
			IF this.modoExec = [MANUAL]
				MESSAGEBOX(_mensaje,16,[ERROR])
			ELSE
				this.UpdLog([ERROR],_mensaje)
			ENDIF 
			RETURN .F.
		ENDIF 
		GO top
		WITH this
			.handle_engine	= ALLTRIM(config.engine)
			.handle_driver	= ALLTRIM(config.driver)
			.handle_server	= ALLTRIM(config.server)
			.handle_puerto	= ALLTRIM(config.puerto)
			.handle_database= ALLTRIM(config.database)
			.handle_passw	= ALLTRIM(config.passw)
			.handle_usuario	= ALLTRIM(config.usuario)
		ENDWITH
		USE IN CONFIG
		RETURN .T.
	ENDPROC

	* Se conecta al servidor de bases de datos remoto.
	PROCEDURE conectar			
		LOCAL __handleNotConnected, __handleAlreadyConnected, __handleConneted, __handleStringConnect
		LOCAL __handleShare

		__handleNotConnected		= -1		&& No se puedo conectar al servidor
		__handleAlreadyConnected	= 0			&& Ya estÔøΩ conectado
		__handleConneted			= 1			&& Se ha Conectado correctamente
		__handleStringConnect		= ""		&& Cadena de ConexiÔøΩn al servidor
		__handleShare				= .F.		&& Indica si la conexion es compartida

		IF this.handle > 0
			IF this.modoExec = [MANUAL]
				MESSAGEBOX("Ya estas conectado a la BD",64,"Informacion")
			ENDIF 
		ENDIF

		* Parametros de Configuracion antes de Conectar
		SQLSETPROP(0,"ConnectTimeOut",15)		&& Tiempo de espera en conectar
		SQLSETPROP(0,"DispLogin",3) 			&& No mostrar dialogo de Conexion ODBC al Servidor

		__handleStringConnect = "DRIVER=" + this.handle_Driver 		+ ";"	;
							  + "SERVER=" + this.handle_Server		+ ";"	;
							  + "UID=" 		+ this.handle_Usuario	+ ";"	;
							  + "PWD=" 		+ this.handle_Passw 	+ ";"	;
							  + "DATABASE="	+ this.handle_Database	+ ";"	;
							  + "PORT=" 	+ this.handle_Puerto
							  *+ this.handle_Parameters

		this.handle = SQLSTRINGCONNECT(__handleStringConnect, __handleShare)

		* Verificar y Preparar ConexiÔøΩn actual
		IF this.handle > 0
		*!*		* Habilitar Buffering
		*!*			SET MULTILOCKS ON
		*!*		* Habilitar Transacciones Manuales en VFP
		*!*			SQLSETPROP(this.handle, 'Transactions', 2)
		*!*		* Aplicar Rollback al desconectar
		*!*			SQLSETPROP(this.handle, 'DisconnectRollback', .T.)
		*!*		* Mostrar Errores sql nativos
		*!*			SQLSETPROP(this.handle, 'DispWarnings', .F.)
		*!*		* Conjuntos de resultado retornados sincrÔøΩnicamente 
		*!*			SQLSETPROP(this.handle, 'Asynchronous', .F.)
		*!*		* SQLEXEC retorna los resultados en una sola vez
		*!*			SQLSETPROP(this.handle, 'BatchMode', .T.)
		*!*		* Tiempo en minutos para que una conexiÔøΩn no usada se desactive (0 = nunca)
		*!*	        SQLSETPROP(this.handle, 'IdleTimeout', 0)
		*!*		* TamaÔøΩo del paquete de datos usado por la conexiÔøΩn (4096)
		*!*			SQLSETPROP(this.handle, 'PacketSize', 4096)
		*!*		* El tiempo de espera, en segundos, antes de retornar un error general
		*!*			SQLSETPROP(this.handle, 'QueryTimeOut', 0)
		*!*		* El tiempo, en milisegundos, hasta que VFP verifique que la instrucciÔøΩn SQL se completÔøΩ
		*!*			SQLSETPROP(this.handle, 'WaitTime', 100)

			* Listo Conectado
			_mensaje = [Conexion establecida!]
			IF this.modoExec = [MANUAL]			
				WAIT WINDOW _mensaje TIMEOUT 2
			ELSE
				this.UpdLog([OK],_mensaje)
			ENDIF
			RETURN .T.
		ELSE
			_mensaje = [No pudo establecerse la conexion con la BD]
			IF this.modoExec = [MANUAL]
				MESSAGEBOX(_mensaje,16,"ERROR")
			ELSE 
				this.UpdLog([ERROR],_mensaje)
			ENDIF
			RETURN .F.
		ENDIF

	ENDPROC

	PROCEDURE desconectar
		* Se desconecta del servidor remoto
		LOCAL __handleValue
		__handleValue = 0		&& Obtener el valor devuelto al desconectar 1, -1 y -2

		IF this.handle >= 1
			__handleValue = SQLDISCONNECT(this.handle)
			this.handle = 0
			IF __handleValue = 1
				RETURN .T.
			ELSE
				RETURN .F.
			ENDIF
		ELSE
			this.handle = 0
			RETURN .T.
		ENDIF		
	ENDPROC

	PROCEDURE scriptCrearBD		
		* Genera script SQL para crear base de datos en servidor remoto.
	ENDPROC
	
	*******
	* Genera script SQL para crear tabla en servidor remoto, a partir de la 
	* estructure de una tabla DBF.
	PROCEDURE scriptCrearTabla			
		PARAMETERS pTabla, pKeyName, pKeyLlave

		__tabla = pTabla
		IF PCOUNT() > 1
			__KeyName	= pKeyName
			__KeyLlave	= pKeyLlave
		ELSE
			__KeyName	= ""
			__KeyLlave	= ""
		ENDIF

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
				?? [char(] + STR(aCampos(i,3),3) + [),]
			CASE INLIST(_fldTipo, [I])
				?? [INT(] + STR(aCampos(i,3),3) + [),]
			CASE INLIST(_fldTipo, [Y],[F],[N],[B])
				?? [decimal(] + STR(aCampos(i,3),3) + [,]+ ALLTRIM(STR(aCampos(i,4),10)) +[),]
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
		? [LOGUPDATE TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP]
		
		IF LEN( __KeyName )>0
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
	ENDPROC
	
	*****
	* Copia datos de una tabla DBF a un archivo de texto.
	* El nombre del cursor fuente debe ser tmpDBF
	*****
	PROCEDURE CopyDbf2Texto		
		LOCAL _numFlds, _fldTipo, _chr, _saveEscape, _continuar
		_chr = CHR(59) 		&& punto y coma ';'
		_continuar = .T.
		_saveEscape = SET([ESCAPE])		
		
		SET ESCAPE ON
		ON ESCAPE STORE .F. TO _continuar
		
		SET CONSOLE OFF 
		SET ALTERNATE TO (this.pathTexto+this.tabla+[.txt])
		SET ALTERNATE ON 
		
		SELECT tmpDBF
		_numFlds = AFIELDS( _aflds )	
		GO TOP
		DO WHILE NOT EOF() AND _continuar
			FOR i=1 TO _numFlds
				IF i=1
					?
				ENDIF
				_fldTipo = _aflds(i,2)
				DO CASE
				CASE _fldTipo = 'M'
					* No procesa campos Memo, se deja un valor vacio...
					?? "" + _chr
					
				CASE INLIST(_fldTipo, 'C')
					* Quito caracteres especiales en cadenas de texto, de otra forma el engine
					* se detiene con un error
					?? this.TextoPlano(EVALUATE(_aflds(i,1))) + _chr

				CASE INLIST(_fldTipo, 'D', 'T') 
					IF EMPTY(EVALUATE(_aflds(i ,1)))
						?? REPLICATE('0',8) + _chr
					ELSE
						*?? TRANSFORM(EVALUATE(_aflds(i,1))) + _chr
						 ?? DTOC(EVALUATE(_aflds(i,1)),1) + _chr
					ENDIF
					
				OTHERWISE
					?? TRANSFORM(EVALUATE(_aflds(i,1))) + _chr				
				ENDCASE
			ENDFOR 
			?? TTOC(DATETIME(),1) + _chr
		
			SKIP
		ENDDO		
		
		IF _continuar = .F.
			? [Proceso interrumpido por el usuario.............................]
		ENDIF 
		
		SET ALTERNATE TO
		SET ALTERNATE OFF
		SET CONSOLE ON
		
		ON ESCAPE
		SET ESCAPE &_saveEscape		
	ENDPROC
	
	*****
	* Controla carga de archivo de texto a tabla remota.
	*****
	PROCEDURE CopyTexto2Sql
		local _cmdSql, _cmdSqlResult, _pathLocal
		local _mensaje, _continuar
		
	* Verificar que exista el archivo de texto:
	* Primero adecua la ruta de acceso al archivo para que la pueda 
	* interpretar el servidor remoto.
	 _pathLocal = strtran(this.pathTexto, [\], [/])
	
	 IF NOT FILE(this.pathTexto + this.tabla + ".txt")
		_mensaje = "El archivo " + this.tabla + ".TXT"+chr(13)+"no ha sido generado..."
		IF this.modoExec = [MANUAL]
			MESSAGEBOX(_mensaje,16,[ERROR])
		ELSE
			this.UpdLog([ERROR],_mensaje)
		ENDIF 		
		return .F.
	 ENDIF

	* Conectarse a la base de datos remota
	* -> La conexion debe estar establecida al llamar este procedimiento

	* TRUNCATE tabla remota
	 _cmdSql = [TRUNCATE ] + this.tabla
	  oDB.UpdLog("INFO", _cmdSql)
	 _cmdSqlResult = SQLEXEC(this.handle, _cmdSql)
	 IF	_cmdSqlResult < 0
		_mensaje = "Error en " + _cmdSql + "..."
		IF this.modoExec = [MANUAL]
			MESSAGEBOX(_mensaje,16,[ERROR SQL])
		ELSE
			this.UpdLog([ERROR],_mensaje)
		ENDIF 		
		RETURN .F.
	 ENDIF
	 oDB.UpdLog("OK", _cmdSql + " .... OK")

	* Preparar comando para copiar archivo de texto
	_cmdSql = ;
	[LOAD DATA LOCAL INFILE '] + _pathLocal + this.tabla + [.txt' ] + ;
	[INTO TABLE ] + this.tabla + [ FIELDS TERMINATED BY ';' ] + ;
	[LINES TERMINATED BY '\r\n' IGNORE 1 LINES ;]

	* Ejecutar comando para copiar archivo
	oDB.UpdLog("INFO", _cmdSql)
	_cmdSqlResult = SQLEXEC(this.handle, _cmdSql)
	 IF	_cmdSqlResult < 0
		_mensaje = "Error en LOAD DATA INFILE " + this.tabla +chr(13)+"Copia no efectuada..."
		IF this.modoExec = [MANUAL]
			MESSAGEBOX(_mensaje,16,[ERROR SQL])
		ELSE
			this.UpdLog([ERROR],_mensaje)
		ENDIF 		
		RETURN .F.
	 ENDIF

	* Desconectar
	* -> La conexion y desconexion se manejan en la rutina que llama este procedimiento

	* Terminar procedimiento
	RETURN

	ENDPROC

	******	
	* Copia campos memo de una tabla DBF a una tabla MySQL. 
	* El nombre de la tabla se recibe como parametro
	* El nombre del cursor fuente debe ser tmpDBF
	*****
	PROCEDURE CopyDbf2Memo
		PARAMETERS __tabla, __where
		LOCAL _numFlds, _fldTipo, _saveEscape, _continuar, _texto
		LOCAL _where, _sqlCommand, _sqlCommandResult
		_continuar	= .T.
		_saveEscape = SET([ESCAPE])		
		IF PCOUNT()>1
			_where = __where
		ELSE 
			_where = ''
		ENDIF 
		
		***** dRendon 04/sep/2018
		* La conexion/desconexion se controlan desde la rutina que llama este proceso
		*	* Comprueba conexion a la base de datos remota para poder continuar
		*	IF NOT this.conectar()
		*		_mensaje = __tabla + "-> No se ejecuto la actualizacion de campos MEMO"
		*		IF this.modoExec = "MANUAL"
		*			MESSAGEBOX(_mensaje,16,[SQL ERROR])
		*		ELSE
		*			this.UpdLog("ERROR",_mensaje)
		*		ENDIF
		*		RETURN 
		*	ENDIF		
		******
	
		ON ESCAPE STORE .F. TO _continuar
		SET ESCAPE ON

		this.UpdLog("INFO","Copiando campos Memo tabla "+ this.tabla)

		SELECT tmpDBF
		_numFlds = AFIELDS( _aflds )	
		GO TOP
		DO WHILE NOT EOF() AND _continuar
			* Siempre reemplazo el campo Memo de la tabla remota porque puede
			* ser que los datos hayan cambiado o se haya borrado algo o todo el contenido

			* NOTA -> Este bucle se puede optimizar para que genere un comando SQL con 
			* todos los campos memo de la tabla, en vez de un comando por cada campo

			FOR i=1 TO _numFlds
				_fldTipo = _aflds(i,2)
				IF _fldTipo <> 'M'
				  * Solo procesamos campos MEMO
					LOOP
				ENDIF

				* Retira caracteres no aceptados por la base de datos remota
				_texto = this.TextoPlano(trim( EVALUATE(_aflds(i,1)) ))
				_sqlCommand = [UPDATE ]+ __tabla +[ SET ]+ _aflds(i,1) + [=?_texto]
				if LEN( _where )>0
					_sqlCommand = _sqlCommand + ' ' + _where
				endif				   
				
				*debug
				*? _sqlCommand

				_sqlCommandResult = SQLEXEC(this.handle, _SqlCommand)
				IF _sqlCommandResult < 0
					_mensaje = "Error ejecutando "+_SqlCommand
					IF this.modoExec = "MANUAL"
						MESSAGEBOX(_mensaje,16,"SQL ERROR")
					ELSE
						this.UpdLog("ERROR", _mensaje)
					ENDIF
				ENDIF 
			ENDFOR

			SELECT tmpDBF
			SKIP	
		ENDDO

		this.UpdLog("OK", "Campos Memo copiados ... ok")

		ON ESCAPE
		SET ESCAPE &_saveEscape	

		***** dRendon 04/sep/2018
		* La conexion/desconexion se controlan desde la rutina que llama este proceso
		* this.desconectar()
		*****

		RETURN 

	ENDPROC

	*****
	* Actualiza eventos y errores en bitacora
	*****
	PROCEDURE UpdLog
		PARAMETERS __evento, __descripc		

		LOCAL _saveAlias
		_saveAlias = ALIAS()
		
		INSERT INTO bitacora (evento,descripc,fregistro) VALUES (__evento,__descripc,DATETIME())
		
		IF LEN( _saveAlias ) > 0
			SELECT ( _saveAlias )
		ENDIF 		
	ENDPROC

	* Reemplaza caracteres no aceptados por la base de datos remota
	PROCEDURE textoPlano

		PARAMETERS pTexto
		return CHRTRANC(pTexto,'·ÈÌÛ˙¡…Õ”⁄Ò—¥“∞;','aeiouAEIOUnN Oo,')

	ENDPROC
		
ENDDEFINE 
