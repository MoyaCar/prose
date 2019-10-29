class CreateTarjetas < ActiveRecord::Migration[5.1]
  def change
    create_table :tarjetas, force: true do |t|
      t.references :sobre
      t.string :nombre, null: false
    end
  end
end
