share_examples_for "a new model" do
  context "when unsaved" do
    it { should_not be_persisted }
  
    it "should allow direct access to properties before it is saved" do
      subject["fur"] = "none"
      subject["fur"].should == "none"
    end
    
    it "should allow access to all properties before it is saved" do
      subject.props.should be_a(Hash)
    end
    
    it "should allow properties to be accessed with a symbol" do
      lambda{ subject.props[:test] = true }.should_not raise_error
    end
  end
end

share_examples_for "a loadable model" do
  context "when saved" do
    before :each do
      subject.save!
    end
    
    it "should load a previously stored node" do
      result = subject.class.load(subject.id)
      result.should == subject
      result.should be_persisted
    end
  end
end

share_examples_for "a saveable model" do
  context "when attempting to save" do
    it "should save ok" do
      subject.save.should be_true
    end
      
    it "should save without raising an exception" do
      subject.save!.should_not raise_error(org.neo4j.graphdb.NotInTransactionException)
    end
    
    context "after save" do
      before(:each) { subject.save}
    
      it { should be_valid }
      
      it { should == subject.class.find(subject.id.to_s) }
      it { should == subject.class.all.to_a[0] }
    end
  end
  
  context "after being saved" do
    # make sure it looks like an ActiveModel model
    include ActiveModel::Lint::Tests
    
    before :each do
      subject.save
    end
    
    it { should be_persisted }
    it { should == subject.class.load(subject.id) }
    it { should be_valid }
    
    it "should be found in the database" do
      subject.class.all.to_a.should include(subject)
    end
    
    it { should respond_to(:to_param) }
    
    #it "should respond to primary_key" do
    #  subject.class.should respond_to(:primary_key)
    #end
    
    it "should render as XML" do
      subject.to_xml.should =~ /^<\?xml version=/
    end
    
    context "attributes" do
      before(:each) do
        @original_subject = @original_subject.attributes
      end
      
      it { should_not include("_neo-id") }
      it { should_not include("_classname") }
    end
  end
end

share_examples_for "an unsaveable model" do 
  context "when attempting to save" do
    it "should not save ok" do
      subject.save.should_not be_true
    end
    
    it "should raise an exception" do
      lambda { subject.save! }.should raise_error
    end
  end
  
  context "after attempted save" do
    before { subject.save }
    
    it { should_not be_valid }
    it { should_not be_persisted }
    
    it "should have a nil id after save" do
      subject.id.should be_nil
    end
  end
end

share_examples_for "a destroyable model" do
  context "when saved" do
    before :each do
      subject.save
    end
    
    it "should remove the model from the database" do
      subject.destroy
      subject.class.load(subject.id).should be_nil
    end
  end
end

share_examples_for "a creatable model" do
  context "when attempting to create" do
    
    it "should create ok" do
      subject.class.create(subject.attributes).should be_true
    end
    
    it "should not raise an exception on #create!" do
      lambda { subject.class.create!(subject.attributes) }.should_not raise_error
    end
    
    it "should save the model and return it" do
      model = subject.class.create(subject.attributes)
      model.should be_persisted
    end
  
    it "should accept attributes to be set" do
      model = subject.class.create(subject.attributes.merge(:name => "Ben"))
      model[:name].should == "Ben"
    end
  end
end

share_examples_for "an uncreatable model" do
  context "when attempting to create" do
    
    it "shouldn't create ok" do
      subject.class.create(subject.attributes).persisted?.should_not be_true
    end
    
    it "should raise an exception on #create!" do
      lambda { subject.class.create!(subject.attributes) }.should raise_error
    end
  end
end

share_examples_for "an updatable model" do
  context "when saved" do
    before { subject.save! }
    
    context "and updated" do
      it "should have altered attributes" do
        lambda { subject.update_attributes!(:a => 1, :b => 2) }.should_not raise_error
        subject[:a].should == 1
        subject[:b].should == 2
      end
    end
  end
end

share_examples_for "an timestamped model" do
  context "when created" do
    before { subject.save! }

    it "updated_at is nil" do
      subject.updated_at.should == nil
    end

    it "created_at is set to DateTime.now" do
      subject.created_at.class.should == DateTime
      subject.created_at.day == DateTime.now.day
    end

  end

  context "when updated" do
    before { subject.save! }
    
    it "created_at is not changed" do
      lambda { subject.update_attributes!(:a => 1, :b => 2) }.should_not change(subject, :created_at)
    end
    
    it "should have altered the updated_at property" do
      lambda { subject.update_attributes!(:a => 1, :b => 2) }.should change(subject, :updated_at)
    end
  end
end

share_examples_for "a non-updatable model" do
  context "then" do
    it "shouldn't update" do
      subject.update_attributes({ :a => 3 }).should_not be_true
    end
  end
end