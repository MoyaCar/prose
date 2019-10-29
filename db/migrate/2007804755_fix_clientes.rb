class FixClientes < ActiveRecord::Migration[5.1]
  def change
    change_table :clientes do |t|
      t.string :nombre_titular
    end
  end
end
