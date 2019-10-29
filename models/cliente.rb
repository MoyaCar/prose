# Un usuario que tiene sobres que retirar. Siempre es el titular de la cuenta
class Cliente < ActiveRecord::Base
  self.table_name = 'clientes'

  has_many :sobres, inverse_of: :cliente
  has_many :logs, as: :usuario

  attr_accessor :codigo
  accepts_nested_attributes_for :sobres

  validates :tipo_documento,
    presence: true
  validates :nro_documento,
    presence: true,
    uniqueness: { scope: :tipo_documento },
    numericality: { only_integer: true }

  validates :codigo,
    numericality: { only_integer: true, allow_nil: true }

  def generar_clave_digital(codigo)
    input = [
      nro_documento.rjust(13, '0'),
      codigo
    ].join

    Digest::SHA256.hexdigest input
  end

  def codigo_valido?(codigo)
    generar_clave_digital(codigo) == clave_digital
  end

  def validar!(codigo)
    if codigo_valido?(codigo) && !bloqueado?
      self.update intentos_fallidos: 0
      self
    else
      Log.info "Intento fallido numero #{self.intentos_fallidos + 1} de cliente #{Novedad::DOCUMENTOS[self.tipo_documento]} #{self.nro_documento} con hash #{generar_clave_digital(codigo)}. Hash correcto #{self.clave_digital}"
      self.update intentos_fallidos: self.intentos_fallidos + 1
      false
    end
  end

  def bloqueado?
    self.intentos_fallidos >= 3
  end

  def admin?
    false
  end
end
