FoxPostg
# Control de versiones

## v1.7.1 - 30.05.2025
1. Se comentan lineas de codigo que fueron usadas para pruebas, para que no afecten la version de produccion.

## v1.7.0 - 29.05.2025
1. Rutina para crear a petici髇 archivos de texto de ordenes de producci髇, sobres y existencias de MP.

## v1.6.0 - 24/may/2025
1. Existencias MP. Se agrega c骴igo para crear archivo de texto
2. Guias de Paquetes. Se va a crear una tabla con el rol de encabezado de documento, como se hace con los pedidos de cliente.

|Tabla    | Descripcion |
|---------|-------------|
| mat042  | Existencias de MP (Producci髇) |
| guiasa  | Se crea tabla para header de Guias de Paquetes |

## v1.5.0 - 04/may/2025
1. Pedidos de Cliente. Se agregan campos para Orden de Compra y Tienda Destino 

| Tabla   | Descripcion |
|---------| ---------------------------------------|
| peda    | Pedidos de Cliente header |

## v1.4.1 - 11/abr/2025
1. Se agrega la llamada a la rutina para crear tabla consolidada del diario de ventas de todas las oficinas 

| Tabla   | Descripcion |
|---------| ---------------------------------------|
| fac010  | Diario de ventas|

## v1.4.0 - 09/abr/2025
1. Se agregan rutinas para copiar data de proeli a archivos de texto:

| Tabla   | Descripcion |
|---------| ---------------------------------------|
| op001   | Ordenes de producci贸n|
| op002   | Sobres de las Ordenes de Producci贸n|
| pre100  | Prefacturas |
| maq012  | Almacenes de producci贸n|

## v1.3.0 - 21/ene/2025
1. A las rutinas para copiar a archivos de texto se agregan las tablas:

| Tabla   | Descripcion |
|---------| ---------------------------------------|
| guias10 | Paquetes enviados a clientes y oficinas|
| cli130  | Ordenes de Retorno |
| cli135  | Ordenes de Retorno Detalle |

## v1.2.1 - 20/ago/2024
1. Se cambia la longitud del c贸digo de art铆culo en el cat谩logo de art铆culos.
De 11 caracteres pasa a 20
2. Se cambia la longitud del c贸digo de art铆culo en reportes y consultas.
