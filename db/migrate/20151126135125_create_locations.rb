class CreateLocations < ActiveRecord::Migration[4.2]
  def change
    create_table :locations do |t|
      t.string :name
      t.string :description
      t.integer :level
      t.integer :location_id
    end
  end
end
