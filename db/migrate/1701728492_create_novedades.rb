class CreateNovedades < ActiveRecord::Migration[5.1]
  def change
    create_table :novedades, force: true do |t|
      t.string :nro_proveedor
      t.string :nro_alternativo
      t.string :tipo_documento, limit: 2
      t.string :nro_documento
      t.string :clave_digital
      t.string :tipo_sid
      t.string :tipo_banco
      t.string :nro_sid
      t.string :nombre
      t.date :fecha
      t.time :hora
    end
  end
end
