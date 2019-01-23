require 'questions_database'
require 'rspec'

RSpec.describe User do
    subject(:user) { User.new('id' => 100, 
                              'fname' => 'Yogi', 
                              'lname' => 'Bear') }

    describe "#initialize" do
        it "assigns id" do
            expect(user.id).to eq(100)
        end

        it "assigns fname" do
            expect(user.fname).to eq('Yogi')
        end

        it "assigns lname" do
            expect(user.lname).to eq('Bear')
        end
    end
end