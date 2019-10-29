# Usuario administrador que puede o no ser superadmin, en cuyo caso puede
# crear otros admins
class Admin < ActiveRecord::Base
  has_many :logs, as: :usuario

  has_secure_password

  # En realidad es un legajo
  validates :nro_documento,
    presence: true,
    uniqueness: true,
    numericality: { only_integer: true }

  # Para la carga de admins sólo permitimos superadmins
  scope :normal, ->{ where super: false }
  scope :super, ->{ where super: true }

  def admin?
    true
  end
end
