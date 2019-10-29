# Archivo de inicio para Rack

# Connection Management para la base de datos
require 'active_record/rack'

# Se encarga de liberar las conexiones
use ActiveRecord::Rack::ConnectionManagement

# Cargar la aplicación completa
require './boot.rb'

# Arrancar la aplicación
run Cuba
