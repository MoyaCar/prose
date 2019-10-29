class AddIntentosFallidosNovedades < ActiveRecord::Migration[5.1]
	def change
		change_table :novedades do |t|
			t.integer :intentos_fallidos, default: 0
		end
	end
end