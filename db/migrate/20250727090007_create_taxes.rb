class CreateTaxes < ActiveRecord::Migration[8.0]
  def change
    create_table :taxes, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.string :name, null: false
      t.decimal :rate, precision: 5, scale: 4, null: false
      t.boolean :active, default: true, null: false
      t.boolean :is_default, default: false, null: false
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :taxes, [ :company_id, :name ], unique: true, where: "deleted_at IS NULL"
    add_index :taxes, [ :company_id, :active ]
    add_index :taxes, [ :company_id, :is_default ]
    add_index :taxes, :deleted_at
  end
end
