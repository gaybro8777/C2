describe Proposal do
  describe "Associatons" do
    it { should belong_to(:client_data).dependent(:destroy) }
    it { should have_many(:steps) }
    it { should have_many(:individual_steps) }
    it { should have_many(:attachments).dependent(:destroy) }
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:approval_steps) }
    it { should have_many(:purchase_steps) }
  end

  describe "Validations" do
    it { should validate_uniqueness_of(:public_id).allow_nil }

    it "disallows requester from also being approver" do
      user = create(:user)
      expect {
        create(:proposal, :with_approver, requester: user, approver_user: user)
      }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it "disallows assigning requester as approver" do
      proposal = create(:proposal)
      expect {
        proposal.add_initial_steps([Steps::Approval.new(assignee: proposal.requester)])
      }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it "disallows assigning approver as requester" do
      proposal = create(:proposal, :with_approver)
      expect {
        proposal.add_requester(proposal.individual_steps.first.assignee_email_address)
      }.to raise_error(/cannot also be Requester/)
    end
  end

  describe 'CLIENT_MODELS' do
    it "contains multiple models" do
      expect(Proposal::CLIENT_MODELS.size).to_not eq(0)
      Proposal::CLIENT_MODELS.each do |model|
        expect(model.ancestors).to include(ActiveRecord::Base)
      end
    end
  end

  describe "#root_step" do
    it "returns the step without a parent" do
      step = create(:serial_step, parent_id: nil)
      proposal = create(:proposal, steps: [step])

      expect(proposal.root_step).to eq step
    end
  end

  describe "#parallel?" do
    it "is true if the root step is a parallel step" do
      proposal = create(:proposal, steps: [create(:parallel_step)])

      expect(proposal).to be_parallel
    end

    it "is false if the root step is not a parallel step" do
      proposal = create(:proposal, steps: [create(:serial_step)])

      expect(proposal).not_to be_parallel
    end
  end

  describe "#serial?" do
    it "is true if the root step is a serial step" do
      proposal = create(:proposal, steps: [create(:serial_step)])

      expect(proposal).to be_serial
    end

    it "is false if the root step is not a serial step" do
      proposal = create(:proposal, steps: [create(:parallel_step)])

      expect(proposal).not_to be_serial
    end
  end

  describe "#delegate?" do
    context "user is a delegate for one of the step users" do
      it "is true" do
        user = create(:user)
        proposal = create(:proposal, delegate: user)

        expect(proposal.delegate?(user)).to eq true
      end
    end

    context "user is not delegate for one of the step users" do
      it "is false" do
        user = create(:user)
        proposal = create(:proposal)

        expect(proposal.delegate?(user)).to eq false
      end
    end
  end

  describe '#currently_awaiting_step_users' do
    it "gives a consistently ordered list when in parallel" do
      proposal = create(:proposal, :with_parallel_approvers)
      approver1, approver2 = proposal.approvers
      expect(proposal.currently_awaiting_step_users).to eq([approver1, approver2])

      proposal.individual_steps.first.update_attribute(:position, 5)
      expect(proposal.currently_awaiting_step_users).to eq([approver2, approver1])
    end

    it "gives only the first approver when linear" do
      proposal = create(:proposal, :with_serial_approvers)
      approver1, approver2 = proposal.approvers
      expect(proposal.currently_awaiting_step_users).to eq([approver1])

      proposal.individual_steps.first.approve!
      expect(proposal.currently_awaiting_step_users).to eq([approver2])
    end
  end

  describe "#name" do
    it "delegates to client data" do
      proposal = build(:proposal)

      expect(proposal.name).to be_nil
    end
  end

  describe "#fields_for_display" do
    it "returns an empty array by deafult" do
      proposal = build(:proposal)

      expect(proposal.fields_for_display).to eq []
    end
  end

  describe '#subscribers' do
    it "returns all approvers, purchasers, observers, and the requester" do
      requester = create(:user)
      proposal = create(:proposal, :with_approval_and_purchase, :with_observers, requester: requester)

      expect(proposal.subscribers.map(&:id).sort).to eq([
        requester.id,
        proposal.approvers.first.id,
        proposal.purchasers.first.id,
        proposal.observers.first.id,
        proposal.observers.second.id
      ].sort)
    end

    it "returns only the requester when it has no other users" do
      proposal = create(:proposal)
      expect(proposal.subscribers).to eq([proposal.requester])
    end

    it "includes observers" do
      observer = create(:user)
      proposal = create(:proposal, requester: observer)
      proposal.add_observer(observer)
      expect(proposal.subscribers).to eq [observer]
    end

    it "removes duplicates" do
      requester = create(:user)
      proposal = create(:proposal, requester: requester)
      proposal.add_observer(requester)
      expect(proposal.subscribers).to eq [requester]
    end
  end

  describe "#eligible_observers" do
    it "identifies eligible observers" do
      observer = create(:user, client_slug: nil)
      proposal = create(:proposal, requester: observer)
      expect(proposal.eligible_observers.to_a).to include(observer)
    end
  end

  describe "#ineligible_approvers" do
    it "identifies ineligible approvers" do
      proposal = create(:proposal)
      expect(proposal.ineligible_approvers).to eq([proposal.requester])
    end
  end

  describe "#subscribers_except_delegates" do
    it "excludes delegates" do
      delegate = create(:user)
      proposal = create(:proposal, :with_approver)
      proposal.approvers.first.add_delegate(delegate)
      expect(proposal.subscribers_except_delegates).to match_array(
        proposal.subscribers - [delegate]
      )
    end
  end

  describe '#reset_status' do
    it 'sets status as approved if there are no approvals' do
      proposal = create(:proposal)
      expect(proposal.pending?).to be true
      proposal.reset_status()
      expect(proposal.approved?).to be true
    end

    it "keeps status as cancelled if the proposal has been cancelled" do
      proposal = create(:proposal, :with_parallel_approvers)
      proposal.individual_steps.first.approve!
      expect(proposal.pending?).to be true
      proposal.cancel!

      proposal.reset_status()
      expect(proposal.cancelled?).to be true
    end

    it 'reverts to pending if an approval is added' do
      proposal = create(:proposal, :with_parallel_approvers)
      proposal.individual_steps.first.approve!
      proposal.individual_steps.second.approve!
      expect(proposal.reload.approved?).to be true
      individuals = proposal.root_step.child_approvals + [Steps::Approval.new(assignee: create(:user))]
      proposal.root_step = Steps::Parallel.new(child_approvals: individuals)

      proposal.reset_status()
      expect(proposal.pending?).to be true
    end

    it 'does not move out of the pending state unless all are approved' do
      proposal = create(:proposal, :with_parallel_approvers)
      proposal.reset_status()
      expect(proposal.pending?).to be true
      proposal.individual_steps.first.approve!

      proposal.reset_status()
      expect(proposal.pending?).to be true
      proposal.individual_steps.second.approve!

      proposal.reset_status()
      expect(proposal.approved?).to be true
    end
  end

  describe "scopes" do
    let(:statuses) { %w(pending approved cancelled) }
    let!(:proposals) { statuses.map{|status| create(:proposal, status: status) } }

    it "returns the appropriate proposals by status" do
      statuses.each do |status|
        expect(Proposal.send(status).pluck(:status)).to eq([status])
      end
    end

    describe '.closed' do
      it "returns approved and and cancelled proposals" do
        expect(Proposal.closed.pluck(:status).sort).to eq(%w(approved cancelled))
      end
    end
  end

  describe '#restart' do
    it "creates new API tokens" do
      proposal = create(:proposal, :with_parallel_approvers)
      proposal.individual_steps.each do |approval|
        create(:api_token, step: approval)
      end

      expect(proposal.api_tokens.size).to eq(2)

      proposal.restart!

      expect(proposal.api_tokens.unscoped.expired.size).to eq(2)
      expect(proposal.api_tokens.unexpired.size).to eq(2)
    end
  end

  describe "#add_observer" do
    it "runs the observation creator service class" do
      proposal = create(:proposal)
      observer = create(:user)
      observation_creator_double = double(run: true)
      allow(ObservationCreator).to receive(:new).with(
        observer: observer,
        proposal_id: proposal.id,
        reason: nil,
        observer_adder: nil
      ).and_return(observation_creator_double)

      proposal.add_observer(observer)

      expect(observation_creator_double).to have_received(:run)
    end
  end

  describe "#tags" do
    it "can add case-insensitive tags" do
      proposal = create(:proposal)
      proposal.tag_list = "foo, bar, BAZ"
      proposal.save!
      expect(proposal.tag_list).to eq(["foo", "bar", "baz"])
    end
  end
end
