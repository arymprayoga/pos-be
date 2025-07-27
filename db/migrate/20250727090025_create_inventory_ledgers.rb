class CreateInventoryLedgers < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_ledgers, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.uuid :item_id, null: false
      t.integer :movement_type, null: false
      t.integer :quantity, null: false
      t.uuid :sales_order_item_id, null: true
      t.text :remarks
      t.string :sync_id
      t.datetime :synced_at
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :inventory_ledgers, [ :company_id, :item_id ]
    add_index :inventory_ledgers, [ :company_id, :movement_type ]
    add_index :inventory_ledgers, [ :company_id, :created_at ]
    add_index :inventory_ledgers, :sync_id, unique: true, where: "sync_id IS NOT NULL"
    add_index :inventory_ledgers, :deleted_at
  end
end
