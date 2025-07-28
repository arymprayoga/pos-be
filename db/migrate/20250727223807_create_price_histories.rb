class CreatePriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :price_histories, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :item, null: false, foreign_key: true, type: :uuid
      t.decimal :old_price, precision: 15, scale: 2, null: false
      t.decimal :new_price, precision: 15, scale: 2, null: false
      t.datetime :effective_date, null: false
      t.text :reason
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :price_histories, [ :company_id, :item_id ]
    add_index :price_histories, [ :company_id, :effective_date ]
    add_index :price_histories, :effective_date
  end
end
