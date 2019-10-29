class CreateSobres < ActiveRecord::Migration[5.1]
  def change
    create_table :sobres, force: true do |t|
      t.references :cliente
      t.integer :posicion
      t.string :nro_proveedor
      t.string :nro_alternativo
      t.string :estado, default: "no_montado", null: false
      t.timestamps
    end
  end
end
