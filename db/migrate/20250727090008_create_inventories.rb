class CreateInventories < ActiveRecord::Migration[8.0]
  def change
    create_table :inventories, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.uuid :item_id, null: false
      t.integer :stock, default: 0, null: false
      t.integer :minimum_stock, default: 0, null: false
      t.integer :reserved_stock, default: 0, null: false
      t.datetime :last_counted_at
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :inventories, [ :company_id, :item_id ], unique: true, where: "deleted_at IS NULL"
    add_index :inventories, [ :company_id, :stock ]
    add_index :inventories, :deleted_at
  end
end
