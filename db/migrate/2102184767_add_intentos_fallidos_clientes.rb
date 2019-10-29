class AddIntentosFallidosClientes < ActiveRecord::Migration[5.1]
  def change
    change_table :clientes do |t|
      t.integer :intentos_fallidos, default: 0
    end
  end
end