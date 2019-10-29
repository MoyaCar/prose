class CreateConfiguraciones < ActiveRecord::Migration[5.1]
  def change
    create_table :configuraciones, force: true do |t|
      t.string :nombre_archivo_novedades, null: false, default: 'novedades.csv'
      t.string :prefijo_nro_proveedor, null: false, default: 'K'
      t.timestamps
    end
  end
end
