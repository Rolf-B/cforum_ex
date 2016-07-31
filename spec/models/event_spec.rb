require 'rails_helper'

RSpec.describe Event, type: :model do
  it "is valid with name, description, start_date and end_date" do
    expect(Event.new(name: 'Foo', description: 'bar', start_date: Time.zone.now, end_date: Time.zone.now)).to be_valid
  end

  it "is invalid w/o name" do
    expect(Event.new(description: 'bar', start_date: Time.zone.now, end_date: Time.zone.now)).to be_invalid
  end
  it "is invalid w/o description" do
    expect(Event.new(name: 'Foo', start_date: Time.zone.now, end_date: Time.zone.now)).to be_invalid
  end
  it "is invalid w/o start_date" do
    expect(Event.new(name: 'Foo', description: 'bar', end_date: Time.zone.now)).to be_invalid
  end
  it "is invalid w/o end_date" do
    expect(Event.new(name: 'Foo', description: 'bar', start_date: Time.zone.now)).to be_invalid
  end

  context "is_open?" do
    it "returns true when the event is open and visible" do
      expect(build(:event).is_open?).to be true
    end
    it "returns false when the event is not open" do
      expect(build(:event, start_date: Date.today - 3, end_date: Date.today - 4).is_open?).to be false
    end
    it "returns false when the event is invisible" do
      expect(build(:event, visible: false).is_open?).to be false
    end
    it "returns true when the event has started but not ended" do
      expect(build(:event, start_date: Date.today - 3, end_date: Date.today + 3).is_open?).to be true
    end
  end
end
