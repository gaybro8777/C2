# Represents a single user's ability to approve, the "leaves" of an approval
# chain
module Steps
  class Individual < Step
    has_one :api_token, -> { fresh }, foreign_key: "step_id"
    # has_many :delegations, through: :assignee, source: :outgoing_delegations
    # has_many :delegates, through: :delegations, source: :assignee
    #
    validate :assignee_is_not_requester
    delegate :full_name, :email_address, to: :assignee, prefix: true
    scope :with_users, -> { includes :assignee }

    self.abstract_class = true

    workflow do
      on_transition { touch } # sets updated_at; https://github.com/geekq/workflow/issues/96

      state :pending do
        event :initialize, transitions_to: :actionable
      end

      state :actionable do
        event :initialize, transitions_to: :actionable do
          halt  # prevent state transition
        end

        event :approve, transitions_to: :approved
        event :restart, transitions_to: :pending
      end

      state :approved do
        on_entry do
          update(approved_at: Time.zone.now)
          notify_parent_approved
          Dispatcher.on_approval_approved(self)
        end

        event :initialize, transitions_to: :actionable do
          notify_parent_approved
          halt  # prevent state transition
        end

        event :restart, transitions_to: :pending
      end
    end

    protected

    def restart
      api_token.try(:expire!)
      super
    end

    def assignee_is_not_requester
      if assignee && assignee == proposal.requester
        errors.add(:assignee, "Cannot be Requester")
      end
    end
  end
end
