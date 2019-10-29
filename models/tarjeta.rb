# Un "plástico" con un nombre que no necesariamente es el del Cliente o Titular
# de cuenta.
class Tarjeta < ActiveRecord::Base
  # Definimos la tabla por la pluralización
  self.table_name = 'tarjetas'

  belongs_to :sobre, inverse_of: :tarjetas
  has_one :cliente, through: :sobre

  validates :nombre,
    presence: true
end
