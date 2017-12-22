class AddConversationToIssues < ActiveRecord::Migration
  def self.up
    add_column :issues, :chyme_conversation_id, :string
  end

  def self.down
    remove_column :issues, :chyme_conversation_id
  end
end
