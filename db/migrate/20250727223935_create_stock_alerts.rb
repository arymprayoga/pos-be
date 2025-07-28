class CreateStockAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_alerts, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :item, null: false, foreign_key: true, type: :uuid
      t.integer :alert_type, null: false, default: 0
      t.integer :threshold_value, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.datetime :last_alerted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :stock_alerts, [ :company_id, :item_id ], unique: true
    add_index :stock_alerts, [ :company_id, :enabled ]
    add_index :stock_alerts, [ :alert_type, :enabled ]
  end
end
