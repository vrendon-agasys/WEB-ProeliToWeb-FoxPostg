FoxPostg
# Control de versiones
## v1.5.0 - 04/may/2025
1. Pedidos de Cliente. Se agregan campos para Ordem de Compra y Tienda Destino 

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
| op001   | Ordenes de producción|
| op002   | Sobres de las Ordenes de Producción|
| pre100  | Prefacturas |
| maq012  | Almacenes de producción|

## v1.3.0 - 21/ene/2025
1. A las rutinas para copiar a archivos de texto se agregan las tablas:

| Tabla   | Descripcion |
|---------| ---------------------------------------|
| guias10 | Paquetes enviados a clientes y oficinas|
| cli130  | Ordenes de Retorno |
| cli135  | Ordenes de Retorno Detalle |

## v1.2.1 - 20/ago/2024
1. Se cambia la longitud del código de artículo en el catálogo de artículos.
De 11 caracteres pasa a 20
2. Se cambia la longitud del código de artículo en reportes y consultas.
