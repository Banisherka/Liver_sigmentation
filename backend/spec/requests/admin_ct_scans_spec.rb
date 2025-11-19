require 'rails_helper'

RSpec.describe "Admin::CtScans", type: :request do
  before { admin_sign_in_as(create(:administrator)) }

  describe "GET /admin/ct_scans" do
    it "returns http success" do
      get admin_ct_scans_path
      expect(response).to be_success_with_view_check('index')
    end
  end

end
