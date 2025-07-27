class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :image_url
      t.boolean :active, default: true, null: false
      t.integer :sort_order, default: 0
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :categories, [ :company_id, :name ], unique: true, where: "deleted_at IS NULL"
    add_index :categories, [ :company_id, :active ]
    add_index :categories, [ :company_id, :sort_order ]
    add_index :categories, :deleted_at
  end
end
