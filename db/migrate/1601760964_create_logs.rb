class CreateLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :logs, force: true do |t|
      t.string :mensaje, null: false
      t.string :severidad, null: false, default: 'info'
      t.references :usuario, polymorphic: true
      t.timestamps
    end
  end
end
