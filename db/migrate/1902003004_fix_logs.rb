class FixLogs < ActiveRecord::Migration[5.1]
  def change
    change_column_default(:logs, :severidad, from: 'info', to: 'INFO')
  end
end
