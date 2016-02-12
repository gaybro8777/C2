FactoryGirl.define do
  factory :approval, class: Steps::Approval do
    proposal
    association :assignee, factory: :user
    status 'pending'
  end
end
