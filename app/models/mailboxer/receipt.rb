class Mailboxer::Receipt < ActiveRecord::Base
  self.table_name = :mailboxer_receipts
  attr_accessible :trashed, :is_read, :is_pinned,:deleted if Mailboxer.protected_attributes?

  belongs_to :notification, :class_name => "Mailboxer::Notification"
  belongs_to :receiver, :polymorphic => :true, :required => false
  belongs_to :message, :class_name => "Mailboxer::Message", :foreign_key => "notification_id", :required => false

  validates_presence_of :receiver

  scope :recipient, lambda { |recipient|
    where(:receiver_id => recipient.id,:receiver_type => recipient.class.base_class.to_s)
  }
  #Notifications Scope checks type to be nil, not Notification because of STI behaviour
  #with the primary class (no type is saved)
  scope :notifications_receipts, lambda { joins(:notification).where(:mailboxer_notifications => { :type => nil }) }
  scope :messages_receipts, lambda { joins(:notification).where(:mailboxer_notifications => { :type => Mailboxer::Message.to_s }) }
  scope :notification, lambda { |notification|
    where(:notification_id => notification.id)
  }
  scope :conversation, lambda { |conversation|
    joins(:message).where(:mailboxer_notifications => { :conversation_id => conversation.id })
  }
  scope :sentbox, lambda { where(:mailbox_type => "sentbox") }
  scope :archived, lambda { where(:mailbox_type => "archived") }
  scope :inbox, lambda { where(:mailbox_type => "inbox") }
  scope :archive, lambda { where(:mailbox_type => "archive") }
  scope :trash, lambda { where(:trashed => true, :deleted => false) }
  scope :not_trash, lambda { where(:trashed => false) }
  scope :deleted, lambda { where(:deleted => true) }
  scope :not_deleted, lambda { where(:deleted => false) }
  scope :is_read, lambda { where(:is_read => true) }
  scope :is_unread, lambda { where(:is_read => false) }
  scope :is_pinned, lambda { where(:is_pinned => true) }

  class << self
    #Marks all the receipts from the relation as read
    def mark_as_read(options={})
      update_receipts({:is_read => true}, options)
    end

    #Marks all the receipts from the relation as unread
    def mark_as_unread(options={})
      update_receipts({:is_read => false}, options)
    end

    #Marks all the receipts from the relation as trashed
    def move_to_trash(options={})
      update_receipts({:trashed => true}, options)
    end

    #Marks all the receipts from the relation as not trashed
    def untrash(options={})
      update_receipts({:trashed => false}, options)
    end

    #Marks the receipt as deleted
    def mark_as_deleted(options={})
      update_receipts({:deleted => true}, options)
    end

    #Marks the receipt as not deleted
    def mark_as_not_deleted(options={})
      update_receipts({:deleted => false}, options)
    end

    #Moves all the receipts from the relation to inbox
    def move_to_inbox(options={})
      update_receipts({:mailbox_type => :inbox, :trashed => false}, options)
    end

    #Moves all the receipts from the relation to sentbox
    def move_to_sentbox(options={})
      update_receipts({:mailbox_type => :sentbox, :trashed => false}, options)
    end

    #Moves all the receipts from the relation to archive
    def move_to_archive(options={})
      update_receipts({:mailbox_type => :archive, :trashed => false}, options)
    end


    def update_receipts(updates, options={})
      ids = where(options).pluck(:id)
      Mailboxer::Receipt.where(:id => ids).update_all(updates) unless ids.empty?
    end

    #Marks the receipt as pinned
    def mark_as_pinned(options={})
      update_receipts({:is_pinned => true}, options)
    end

    def mark_as_unpinned(options={})
      update_receipts({:is_pinned => false}, options)
    end
  end


  #Marks the receipt as deleted
  def mark_as_deleted
    update(:deleted => true)
  end

  #Marks the receipt as not deleted
  def mark_as_not_deleted
    update(:deleted => false)
  end

  #Marks the receipt as read
  def mark_as_read
    update(:is_read => true)
  end

  #Marks the receipt as unread
  def mark_as_unread
    update(:is_read => false)
  end

  #Marks the receipt as trashed
  def move_to_trash
    update(:trashed => true)
  end

  #Marks the receipt as not trashed
  def untrash
    update(:trashed => false)
  end

  #Marks the receipt as not pinned
  def mark_as_unpinned
    update(:is_pinned => false)
  end

  def mark_as_pinned
    update(:is_pinned => true)
  end

  #Moves the receipt to inbox
  def move_to_inbox
    update(:mailbox_type => :inbox, :trashed => false)
  end

  #Moves the receipt to sentbox
  def move_to_sentbox
    update(:mailbox_type => :sentbox, :trashed => false)
  end

  #Moves the receipt to archive
  def move_to_archive
    update(:mailbox_type => :archive, :trashed => false)
  end


  #Returns the conversation associated to the receipt if the notification is a Message
  def conversation
    message.conversation if message.is_a? Mailboxer::Message
  end

  #Returns if the participant have read the Notification
  def is_unread?
    !is_read
  end

  #Returns if the participant have trashed the Notification
  def is_trashed?
    trashed
  end

  protected

  if Mailboxer.search_enabled
    if Mailboxer.search_engine == :pg_search
      include PgSearch::Model
      pg_search_scope :search, associated_against: { message: { subject: 'A', body: 'B' } }, using: { tsearch: { prefix: true, negation: true, dictionary: "english" } }
    else
      searchable do
        text :subject, :boost => 5 do
          message.subject if message
        end
        text :body do
          message.body if message
        end
        integer :receiver_id
      end
    end
  end
end
