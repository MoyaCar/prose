# Instalación

    bundle install

# Uso

El comando `rackup` levanta el servidor en `http://localhost:9292`. En `/`
tenemos la bienvenida, que explica el funcionamiento de la terminal. Las
siguientes pantallas (`/dni`, `/codigo`) piden un DNI y código de acceso. En
esta etapa esos datos están precargados en la base de datos. Luego de
autenticar al usuario con el código de acceso, dirigimos a la interfaz de carga
de sobre (`/carga`) o de extracción de sobre (`/extraccion`) según el usuario
sea o no administrador del sistema. Si el usuario no existe o el código es
incorrecto, volvemos al inicio informando del error.

En la pantalla de carga `/carga` le indicamos al administrador cómo presentar
el sobre al lector de código de barras. El código leído deberá ser un DNI
existente en la base de datos (caso contrario mostramos un error y anulamos la
carga), cargamos el usuario y buscamos una ubicación libre. En caso de no
haber, informamos y anulamos la carga. Si hay una ubicación libre, ubicamos al
motor en dicha posición y luego indicamos al nucleo posición de carga,
esperando la respuesta. Si la carga fue exitosa (el nucleo devuelve código de
*ok*), guardamos los datos en la base de datos. Caso contrario (el nucleo
devuelve código de *error*) informamos que hubo algún error en la carga, y
volvemos al inicio.

En la pantalla de extracción `/extraccion`, verificamos que exista un sobre
para el usuario. En caso contrario, informamos y volvemos al inicio. Si hay un
sobre, ponemos al motor en su ubicación y luego indicamos al nucleo que lo
extraiga. Si se extrajo el sobre (el nucleo devuelve código de *ok*),
eliminamos el sobre de la base de datos, liberando la posición, y vamos al
inicio informando que todo fue correcto. Si no se extrajo el sobre (el nucleo
devuelve código de *error*), indicamos al nucleo que lo guarde, volvemos al
inicio e informamos.
