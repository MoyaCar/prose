class FixNovedades < ActiveRecord::Migration[5.1]
  def change
    change_table :novedades do |t|
      t.string :tipo_sid_2
      t.string :tipo_banco_2
      t.string :nro_sid_2
      t.string :nombre_titular
    end
  end
end
