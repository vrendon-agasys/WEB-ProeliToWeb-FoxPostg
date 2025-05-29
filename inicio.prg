*******************************************************************************
* PROJ		: FoxMySQL -> FoxPostg
* Prog		: Inicio.prg
* Author	: dRendon
* Creacion	: 05/sep/2018 -> 11/may/2022
* -----------------------------------------------------------------------------
* dRendon 11/may/2022
* Se adapta el programa anterior que trabajaba con MySQL para 
* utilizar ahora PostgreSQL como servidor remoto.
* -----------------------------------------------------------------------------
* dRendon 29/Jun/2022
* Por restricciones de PostgreSQL, se modifica el flujo de proceso:
*		Ahora se generan los archivos de texto, sin llamar los comandos SQL remotos
*		Al final de la generación, se va a llamar al archivo "copyTxt2Postg.bat"
*		localizado en el directorio donde se ejecuta este EXE
* -----------------------------------------------------------------------------
* v1.3.0 | 21/ene/2025 | dRendon 
* A las rutinas para copiar a archivos de texto se agregan las tablas:
*	guias10 | Paquetes enviados a clientes y oficinas|
*	cli130  | Ordenes de Retorno |
*	cli135  | Ordenes de Retorno Detalle |
* -----------------------------------------------------------------------------

PARAMETERS _modoExec

IF PCOUNT() < 1
	_modoExec = "MANUAL"
ENDIF
_modoExec=UPPER(_modoExec)
IF _modoExec <> "AUTO" ;
			AND _modoExec <> "MANUAL" ;
			AND _modoExec <> "PARIDADES" ;
			AND _modoExec <> "EXISTENCIAS" ;
			AND _modoExec <> "ORDPROD" 
	MESSAGEBOX("No se reconoce " + _modoExec + " como modo de ejecucion",64,"ATENCION")
	RETURN 
ENDIF

*SET STEP ON 

*-------------------------------------------------------------------------------
*	Creacion de Variables Publicas:										
*	oApp	Contiene el objeto aplicacion
*	oCtrl	Clase con métodos de control
*	oDB		Clase con metodos en la base de datos
*-------------------------------------------------------------------------------
PUBLIC oApp, oCtrl, oDB, oSecAES

_screen.AutoCenter = .T.
_screen.Width = 800
_screen.Height = 600

set asserts off
SET ESCAPE off
_screen.Caption	= 'Fox To PostgreSQL'
*_screen.WindowState	= 2		&& Ventana maximizada
_screen.WindowState	= 0		  && pantalla normal
set asserts on
SET ESCAPE on

*-------------------------------------------------------------------------------
*	Bibliotecas de clase									
*-------------------------------------------------------------------------------
set classlib to aplicacion

PUBLIC oApp, oCtrl, oDB, oSecAES

oApp 	= CreateObject( 'entorno' 	)		&& aplicacion.vcx
oCtrl	= CREATEOBJECT( 'controll'	)		&& aplicacion.vcx
oDB		= CREATEOBJECT( 'model'			)		&& aplicacion.vcx
*oSecAES= CREATEOBJECT( 'Seguridad.AES'	)	&& Seguridad.vcx

oApp.modoExec = _modoExec

ON SHUTDOWN TerminarPrograma()
ON ERROR DO TrapError with LINENO(), PROGRAM(), MESSAGE(), MESSAGE(1)

set sysmenu to
oApp.QuitarBarras()
oApp.PonerSETs()
IF oDB.Setup() = .F.
	TerminarPrograma()
	return
ENDIF

*** NOTA IMPORTANTE
*   ---------------
*	Se sugiero ejecutar este programa en el directorio donde estan los
*	diccionarios de ProELI porque las rutinas heredadas no consideran las
*	variables oApp.pathProeli ni oApp.pathDirsdo
***

*oSplash = CREATEOBJECT([formSplash])
*oSplash.Show()
*WAIT [] TIMEOUT 2
DO CASE
	CASE oApp.modoExec = "MANUAL"
		*_screen.Picture = 'sombra.png'
		_screen.BackColor = RGB(120,130,140)
		do mainMenu.mpr
		READ EVENTS
		
	CASE oApp.modoExec = "AUTO"
		oCtrl.FlujoContinuo()
		
	CASE oApp.modoExec = "PARIDADES"
		oCtrl.UpdParidades()
		
	CASE oApp.modoExec = "EXISTENCIAS"
		oCtrl.UpdExistencias()

	CASE oApp.modoExec = "ORDPROD"
		oCtrl.UpdOrdProd()
ENDCASE

ON SHUTDOWN 

oApp.PonerBarras()	
set sysmenu to default

clear events
close all	
release all extend
clear

RETURN

**********************************************
  PROCEDURE TerminarPrograma()
*
* Rutina para terminar programa
* Se cierran tablas y se limpia la memoria
*

oApp.PonerBarras()	
set sysmenu to default

clear events
close all	
release all extend
clear

RETURN

*****************************************************************
PROCEDURE TrapError(nLine, cprog, cMessage, cMessage1)
*
* "Cacha" el error y genera un registro con los datos respectivos
* 
OnError = ON( [ERROR] )

ON ERROR

IF NOT FILE( [ERRORS.DBF] )
	CREATE TABLE errors 	;
	(	fecha	 date,		;
		hora	 Char( 5 ),	;
		LineNum	 Integer,	;
		ProgName Char(30),	;
		Msg		 Char(240),	;
		CodeLine Char(240)	)
ENDIF

IF NOT USED( [ERRORS] )
	USE errors IN 0
ENDIF
SELECT errors

INSERT INTO errors VALUES ;
( DATE(), TIME(), nLine, cprog, cMessage, cMessage1)
USE IN errors

cStr = [Error en la linea ] + TRANSFORM( nLine ) + [ de ] + ;
		cProg + [:] + CHR(13) + cMessage + CHR(13) + ;
	   [Codigo que causo el error: ] + CHR(13) + cMessage1

MESSAGEBOX(cStr, 64, [Error])	

return
