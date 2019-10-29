# La configuración de la app. Se asume un sólo registro en la BD.
class Configuracion < ActiveRecord::Base
  # Definimos la tabla por la pluralización
  self.table_name = "configuraciones"

  validates :nombre_archivo_novedades,
    presence: true

  def self.config
    # Buscamos la última configuración guardada. Si no hubiera, inicializamos
    # una con los valores default
    Configuracion.order(:created_at).first || Configuracion.new
  end

  # Delegar cada campo por conveniencia
  def self.nombre_archivo_novedades
    config.nombre_archivo_novedades
  end

  def self.prefijo_nro_proveedor
    config.prefijo_nro_proveedor
  end

  # Archivo de configuración de entorno
  def self.entorno
    YAML::load(IO.read("config.yml"))
  end

  def self.path_archivo_novedades
    File.join path_base_novedades, nombre_archivo_novedades
  end

  def self.path_base_novedades
    File.join path_base_archivos, "novedades"
  end

  def self.path_base_archivos
    entorno["csv"]["path"]
  end
end
