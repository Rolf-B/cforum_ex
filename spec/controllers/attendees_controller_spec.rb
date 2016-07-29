require 'rails_helper'

RSpec.describe AttendeesController, type: :controller do

  let(:event) { create(:event) }
  let(:user) { create(:user) }

  describe "GET #new" do
    it "assigns a new attendee as @attendee" do
      get :new, event_id: event.event_id
      expect(assigns(:attendee)).to be_a_new(Attendee)
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new Attendee" do
        expect {
          post :create, event_id: event.event_id, attendee: attributes_for(:attendee)
        }.to change(Attendee, :count).by(1)
      end

      it "assigns a newly created attendee as @attendee" do
        post :create, event_id: event.event_id, attendee: attributes_for(:attendee)
        expect(assigns(:attendee)).to be_a(Attendee)
        expect(assigns(:attendee)).to be_persisted
      end

      it "redirects to the event attendee" do
        post :create, event_id: event.event_id, attendee: attributes_for(:attendee)
        expect(response).to redirect_to(event)
      end

      it "fills in the name when created as a user" do
        sign_in user

        expect {
          post :create, event_id: event.event_id, attendee: attributes_for(:attendee, name: nil)
        }.to change(Attendee, :count).by(1)
      end
    end

    context "with invalid params" do
      it "assigns a newly created but unsaved attendee as @attendee" do
        post :create, event_id: event.event_id, attendee: attributes_for(:attendee, name: nil)
        expect(assigns(:attendee)).to be_a_new(Attendee)
      end

      it "re-renders the 'new' template" do
        post :create, event_id: event.event_id, attendee: attributes_for(:attendee, name: nil)
        expect(response).to render_template("new")
      end
    end
  end

  describe "GET #edit" do
    let(:attendee) { create(:attendee, event: event, user: user) }
    before(:each) { sign_in user }

    it "assigns the requested event as @event" do
      get :edit, event_id: event.to_param, id: attendee.to_param
      expect(assigns(:event)).to eq(event)
    end

    it "assigns the requested attendee as @attendee" do
      get :edit, event_id: event.to_param, id: attendee.to_param
      expect(assigns(:attendee)).to eq(attendee)
    end
  end


  describe "PUT #update" do
    context "with valid params" do
      let(:attendee) { create(:attendee, event: event, user: user) }
      let(:new_attributes) {
        {comment: 'Foo bar'}
      }

      before(:each) do
        attendee
        sign_in user
      end

      it "updates the requested attendee" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: new_attributes
        attendee.reload
        expect(attendee.comment).to eql('Foo bar')
      end

      it "assigns the requested event as @event" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: new_attributes
        expect(assigns(:event)).to eq(event)
      end

      it "assigns the requested attendee as @attendee" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: new_attributes
        attendee.reload
        expect(assigns(:attendee)).to eq(attendee)
      end

      it "redirects to the event" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: new_attributes
        expect(response).to redirect_to(event)
      end
    end

    context "with invalid params" do
      let(:attendee) { create(:attendee, event: event, user: user) }
      let(:invalid_attributes) { { planned_arrival: '' } }

      before(:each) do
        attendee
        sign_in user
      end

      it "assigns the event as @event" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: invalid_attributes
        expect(assigns(:event)).to eq(event)
      end

      it "assigns the attendee as @attendee" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: invalid_attributes
        expect(assigns(:attendee)).to eq(attendee)
      end

      it "re-renders the 'edit' template" do
        put :update, event_id: event.to_param, id: attendee.to_param, attendee: invalid_attributes
        expect(response).to render_template("edit")
      end
    end
  end


  describe "DELETE #destroy" do
    let(:attendee) { create(:attendee, event: event, user: user) }
    before(:each) do
      attendee # ugly but necessary, due to lazyness
      sign_in user
    end

    it "destroys the requested attendee" do
      expect {
        delete :destroy, event_id: event.event_id, id: attendee.to_param
      }.to change(Attendee, :count).by(-1)
    end

    it "redirects to the event" do
      delete :destroy, event_id: event.event_id, id: attendee.to_param
      expect(response).to redirect_to(event)
    end
  end

end
