class Log < ActiveRecord::Base
  @@logger = nil
  @@usuario_actual = nil

  # El usuario logueado cuando ocurrió el evento
  belongs_to :usuario, inverse_of: :logs, polymorphic: true

  validates :mensaje, presence: true
  validates :severidad, inclusion: { in: %w{DEBUG INFO WARN ERROR FATAL UNKNOWN} }

  def self.inicializar(log_level)
    @@logger = Logger.new STDOUT

    @@logger.info "Configurando Logger.level en #{log_level}"
    @@logger.level = Object.const_get log_level
  end

  # Método genérico de log, usa el usuario actual y loguea en el logger
  def self.log(severidad, mensaje)
    create severidad: severidad, mensaje: mensaje, usuario: usuario_actual

    @@logger.add(Logger::Severity.const_get(severidad)) { mensaje }
  end

  # Helpers para loguear rápido con dicha severidad
  def self.info(mensaje)
    self.log :INFO, mensaje
  end

  def self.error(mensaje)
    self.log :ERROR, mensaje
  end

  def self.debug(mensaje)
    self.log :DEBUG, mensaje
  end
  def self.warn(mensaje)
    self.log :WARN, mensaje
  end
  def self.fatal(mensaje)
    self.log :FATAL, mensaje
  end

  def self.usuario_actual
    @@usuario_actual
  end

  def self.usuario_actual=(usuario)
    @@usuario_actual = usuario
  end

  # Para loguear desde los tests y no crear registros
  def self.logger
    @@logger
  end
end
