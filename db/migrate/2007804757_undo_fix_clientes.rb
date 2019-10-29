class UndoFixClientes < ActiveRecord::Migration[5.1]
  def change
    remove_column :clientes, :nombre_titular, :string 
  end
end
