# Un sobre relacionado con un único titular de cuenta, pero posiblemente con
# varias tarjetas. Según la documentación:
#
#   "El caso práctico es cuando se distribuyen más de 2 tarjetas (ej: titular +
#   2 adicionales)"
#

class Sobre < ActiveRecord::Base
  belongs_to :cliente, inverse_of: :sobres
  has_many :tarjetas

  # Registros de Sobres sin sobre físico
  scope :no_montados, -> { where estado: "no_montado" }
  # Sobres con sobre físico cargado
  scope :montados, -> { where estado: "montado" }
  # Sobres entregados al cliente
  scope :entregados, -> { where estado: "entregado" }
  # Sobres descargados por el banco
  scope :descargados, -> { where estado: "descargado" }
  # Sobres entregados por el banco de forma manual al usuario por algun error en el funcionamiento del cicuito
  scope :manualmente, -> { where estado: "manualmente" }

  validates :posicion,
    uniqueness: {allow_nil: true},
    numericality: {greater_than_or_equal_to: 0, less_than: Nucleo::POSICIONES, allow_nil: true}
  validates :estado,
    inclusion: {in: %w{no_montado montado entregado descargado manualmente}}

  def novedad
    Novedad.where(nro_proveedor: nro_proveedor).take || Novedad.new
  end
end
