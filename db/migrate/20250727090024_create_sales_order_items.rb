class CreateSalesOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_order_items, id: :uuid do |t|
      t.uuid :sales_order_id, null: false
      t.uuid :item_id, null: false
      t.decimal :price, precision: 15, scale: 2, null: false
      t.integer :quantity, null: false
      t.decimal :tax_rate, precision: 5, scale: 4, default: 0
      t.decimal :tax_amount, precision: 15, scale: 2, default: 0
      t.string :sync_id
      t.datetime :synced_at
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :sales_order_items, :sync_id, unique: true, where: "sync_id IS NOT NULL"
    add_index :sales_order_items, :deleted_at
  end
end
