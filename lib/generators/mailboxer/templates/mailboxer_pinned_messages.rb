class MailboxerPinnedMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :mailboxer_receipts, :is_pinned, :boolean, default: false
  end
end
