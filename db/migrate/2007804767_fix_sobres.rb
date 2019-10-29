class FixSobres < ActiveRecord::Migration[5.1]
  def change
    change_table :sobres do |t|
      t.string :tipo_sid
      t.string :tipo_banco
      t.string :nro_sid
      t.string :tipo_sid_2
      t.string :tipo_banco_2
      t.string :nro_sid_2
    end
  end
end
