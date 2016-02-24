describe ProposalMailer do
  include MailerSpecHelper

  describe "#proposal_created_confirmation" do
    let(:mail) { ProposalMailer.proposal_created_confirmation(proposal) }

    it_behaves_like "a proposal email"

    it "has the corect subject" do
      expect(mail.subject).to eq("Request #{proposal.public_id}: #{proposal.name}")
    end

    it "renders the receiver email" do
      expect(mail.to).to eq([proposal.requester.email_address])
    end

    it "uses the default sender name" do
      expect(sender_names(mail)).to eq(["C2"])
    end
  end

  describe "#emergency_proposal_created_confirmation" do
    let(:mail) { ProposalMailer.emergency_proposal_created_confirmation(proposal) }

    it_behaves_like "a proposal email"

    it "contains information about the proposal" do
      expect(mail.body.encoded).to include(proposal.client_data.name)
    end
  end

  def proposal
    @proposal ||= create(:ncr_work_order, :is_emergency).proposal
  end
end