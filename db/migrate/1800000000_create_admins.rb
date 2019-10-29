class CreateAdmins < ActiveRecord::Migration[5.1]
  def change
    create_table :admins, force: true do |t|
      t.string :nombre, null: false
      t.string :nro_documento, null: false
      t.string :password_digest, null: false
      t.boolean :super, default: false
    end
  end
end
