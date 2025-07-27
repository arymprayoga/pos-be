class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies, id: :uuid do |t|
      t.string :name, null: false
      t.text :address
      t.string :phone
      t.string :email
      t.jsonb :settings, default: {}
      t.string :currency, default: 'IDR', null: false
      t.string :timezone, default: 'Asia/Jakarta', null: false
      t.boolean :active, default: true, null: false
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :companies, :email, unique: true, where: "deleted_at IS NULL"
    add_index :companies, :active
    add_index :companies, :deleted_at
    add_index :companies, :created_at
  end
end
