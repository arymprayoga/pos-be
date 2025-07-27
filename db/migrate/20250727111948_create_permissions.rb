class CreatePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :permissions, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :resource, null: false
      t.string :action, null: false
      t.text :description
      t.boolean :system_permission, default: false, null: false
      t.uuid :created_by
      t.uuid :updated_by
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :permissions, [ :company_id, :name ], unique: true
    add_index :permissions, [ :company_id, :resource, :action ]
    add_index :permissions, :system_permission
    add_index :permissions, :deleted_at
  end
end
