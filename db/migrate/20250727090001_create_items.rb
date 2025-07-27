class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.uuid :category_id, null: false
      t.string :sku, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 15, scale: 2, null: false
      t.string :image_url
      t.jsonb :variants, default: {}
      t.boolean :active, default: true, null: false
      t.boolean :track_inventory, default: true, null: false
      t.integer :sort_order, default: 0
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :items, [ :company_id, :sku ], unique: true, where: "deleted_at IS NULL"
    add_index :items, [ :company_id, :category_id ]
    add_index :items, [ :company_id, :active ]
    add_index :items, [ :company_id, :name ]
    add_index :items, :deleted_at
  end
end
