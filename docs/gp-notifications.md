# Avisos dentro de Dynamics GP

## Fuentes verificadas

Microsoft documenta la ventana **Administration → Utilities → System → Send Users Message**, con notificación, tarea con recordatorio o ambas. [System Administration Guide](https://learn.microsoft.com/en-us/dynamics-gp/installation/systemadminguide).

Dan Peltier, de Microsoft, identifica `syUserMessages` como `SY30000` y enumera CMPANYID, Offline_Message, SEQNUMBR y USERID en su [publicación de cambios de tablas/columnas](https://community.dynamics.com/blogs/post/?postid=4ec1d036-378b-4c0b-ab07-60184d988f3c). Es una lista acumulada desde GP 2013 RTM, no una afirmación de que todas esas tablas se introdujeran específicamente en GP 2015.

La función nativa y los nombres de tabla/campos están documentados. No se encontró una especificación pública de Microsoft que garantice inserciones SQL de terceros, el algoritmo de secuencia o recepción del aviso después de retirar ACTIVITY. El adaptador de este repositorio es una implementación a validar en el build del cliente, no una API certificada.

## Implementación

SP_LOGOUTGPUSER_BY_QUOTE retira una sesión y crea un evento propio. SP_POST_GP_NOTIFICATION verifica la tabla nativa, resuelve el mensaje para el usuario/compañía y asigna una secuencia global MAX+1 con bloqueo exclusivo. Publica sin alterar mensajes existentes y registra QUEUED_GP. Todo ocurre en la transacción del retiro: el error del adaptador revierte la eliminación.

La compañía se resuelve antes de borrar ACTIVITY, usando CMPNYNAM en SY01500. Un nombre duplicado o inexistente detiene el retiro con aviso. No se toma la primera coincidencia ni se inventa CMPANYID=0.

PENDING es un evento local aún no publicado, por ejemplo al usar NotifyInGP=0. QUEUED_GP no equivale a entregado, visto ni leído. El evento local no es por sí mismo una notificación de GP.

## Validación en GP

1. Con un usuario de prueba conectado, usar Send Users Message y comprobar el aviso desde la interfaz nativa.
2. Revisar el esquema de SY30000 y la fila generada: tipos, tamaños, compañía, secuencia y cualquier columna adicional. Comparar con los cuatro campos usados por el adaptador.
3. Probar el job sobre ese usuario en un ambiente descartable. Verificar que el mensaje se presenta después del retiro, no solo que existe la fila SQL. Confirmar la demora con procesos largos abiertos y al reconectarse.
4. Probar dos usuarios/dos compañías y envío nativo concurrente. Confirmar que no se mezclan destinatarios ni se sobrescriben mensajes.

Si el cliente deja de consultar mensajes después del retiro, habrá que avisar **antes** y aplicar un período de gracia, manteniendo la ejecución cada minuto. No se ha introducido esa demora sin validar el comportamiento requerido por el cliente.

Consulta de metadatos (solo lectura) en la base de sistema GP:

```sql
EXEC sys.sp_help N'dbo.SY30000';
EXEC sys.sp_helpindex N'dbo.SY30000';
```
