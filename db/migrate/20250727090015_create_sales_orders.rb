class CreateSalesOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_orders, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.string :order_no, null: false
      t.decimal :sub_total, precision: 15, scale: 2, null: false
      t.decimal :discount, precision: 15, scale: 2, default: 0
      t.decimal :tax_rate, precision: 5, scale: 4, default: 0
      t.decimal :tax_amount, precision: 15, scale: 2, default: 0
      t.decimal :grand_total, precision: 15, scale: 2, null: false
      t.uuid :payment_method_id, null: false
      t.decimal :paid_amount, precision: 15, scale: 2, null: false
      t.decimal :change_amount, precision: 15, scale: 2, default: 0
      t.integer :status, null: false, default: 0
      t.string :sync_id
      t.datetime :synced_at
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :sales_orders, [ :company_id, :order_no ], unique: true, where: "deleted_at IS NULL"
    add_index :sales_orders, [ :company_id, :status ]
    add_index :sales_orders, [ :company_id, :created_at ]
    add_index :sales_orders, :sync_id, unique: true, where: "sync_id IS NOT NULL"
    add_index :sales_orders, :deleted_at
  end
end
