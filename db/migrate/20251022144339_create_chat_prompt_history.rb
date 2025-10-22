class CreateChatPromptHistory < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_prompt_histories do |t|
      t.string :ip_address, null: false
      t.string :app_type, null: false, default: "legacy"
      t.text :prompt, null: false
      t.timestamps
    end

    add_index :chat_prompt_histories, [ :ip_address, :prompt ], unique: true
  end
end
