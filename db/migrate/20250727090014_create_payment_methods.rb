class CreatePaymentMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_methods, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.boolean :is_default, default: false, null: false
      t.integer :sort_order, default: 0
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :payment_methods, [ :company_id, :name ], unique: true, where: "deleted_at IS NULL"
    add_index :payment_methods, [ :company_id, :active ]
    add_index :payment_methods, [ :company_id, :is_default ]
    add_index :payment_methods, :deleted_at
  end
end
