describe "Radiant::ResourceResponses" do
  before :each do
    @klass = Class.new(ApplicationController)
    @klass.extend Radiant::ResourceResponses
  end
  
  describe "extending the controller" do
    it "should add the responses method" do
      @klass.should respond_to(:responses)
    end
    
    it "should return a response collector" do
      @klass.responses.should be_kind_of(Radiant::ResourceResponses::Collector)
    end
    
    it "should yield the collector to the passed block" do
      @klass.responses {|r| r.should be_kind_of(Radiant::ResourceResponses::Collector) }
    end
    
    it "should add a response_for instance method" do
      @klass.new.should respond_to(:response_for)
    end
    
    it "should add a wrap instance method" do
      @klass.new.should respond_to(:wrap)
    end
    
    it "should duplicate on inheritance" do
      @subclass = Class.new(@klass)
      @subclass.responses.should_not equal(@klass.responses)
    end
  end
  
  describe "responding to configured formats" do
    before :each do
      @default = lambda { render :text => "Hello, world!" }
      @klass.responses do |r|
        r.plural.default(&@default)
      end
      @responder = double('responder')
      @instance = @klass.new
      @instance.stub(:respond_to).and_yield(@responder)
    end

    describe "when wrapping a block" do
      it "should evaluate the block in the context of the controller" do
        @instance.send(:instance_variable_set, "@foo", "foo")
        @instance.wrap(Proc.new { @foo }).call.should == 'foo'
      end
    end
    
    it "should apply the default block to the :any format" do
      @instance.should_receive(:wrap).with(@default).and_return(@default)
      @responder.should_receive(:any).with(&@default)
      @instance.response_for(:plural)
    end
    
    it "should apply the publish block to the published formats before the default format" do
      @pblock = lambda { render :text => 'bar' }
      @klass.responses.plural.publish(:xml, :json, &@pblock)
      @instance.should_receive(:wrap).with(@pblock).twice.and_return(@pblock)
      @instance.should_receive(:wrap).with(@default).and_return(@default)
      @responder.should_receive(:xml).with(&@pblock).once.ordered
      @responder.should_receive(:json).with(&@pblock).once.ordered
      @responder.should_receive(:any).with(&@default).once.ordered
      @instance.response_for(:plural)
    end
    
    it "should apply custom formats before the published and default formats" do
      @iblock = lambda { render :text => 'baz' }
      @pblock = lambda { render :text => 'bar' }
      @klass.responses.plural.iphone(&@iblock)
      @klass.responses.plural.publish(:xml, &@pblock)
      @instance.should_receive(:wrap).with(@iblock).and_return(@iblock)
      @instance.should_receive(:wrap).with(@pblock).and_return(@pblock)
      @instance.should_receive(:wrap).with(@default).and_return(@default)
      @responder.should_receive(:iphone).with(&@iblock).once.ordered
      @responder.should_receive(:xml).with(&@pblock).once.ordered
      @responder.should_receive(:any).with(&@default).once.ordered
      @instance.response_for(:plural)
    end
    
    it "should apply the :any format when the default block is blank" do
      @klass.responses.plural.send(:instance_variable_set, "@default", nil)
      @responder.should_receive(:any).with(no_args())
      @instance.response_for(:plural)
    end
    
    it "should apply a custom format when no block is given" do
      @klass.responses.plural.iphone
      @instance.should_receive(:wrap).with(@default).and_return(@default)
      @responder.should_receive(:iphone)
      @responder.should_receive(:any)
      @instance.response_for(:plural)
    end
  end
end

describe Radiant::ResourceResponses::Collector do
  before :each do
    @collector = Radiant::ResourceResponses::Collector.new
  end
  
  it "should provide a Response object as the default property" do
    @collector.plural.should be_kind_of(Radiant::ResourceResponses::Response)
  end
  
  it "should be duplicable" do
    @collector.should be_duplicable
  end
  
  it "should duplicate its elements when duplicating" do
    @collector.plural.html
    @duplicate = @collector.dup
    @collector.plural.should_not equal(@duplicate.plural)
  end
end

describe Radiant::ResourceResponses::Response do
  before :each do
    @response = Radiant::ResourceResponses::Response.new
  end
  
  it "should duplicate its elements when duplicating" do
    @response.default { render :text => "foo" }
    @response.html
    @response.publish(:xml) { render }
    @duplicate = @response.dup
    @response.blocks.should_not equal(@duplicate.blocks)
    @response.default.should_not equal(@duplicate.default)
    @response.publish_block.should_not equal(@duplicate.publish_block)
    @response.publish_formats.should_not equal(@duplicate.publish_formats)
    @response.block_order.should_not equal(@duplicate.block_order)
  end

  it "should accept a default response block" do
    @block = lambda { render :text => 'foo' }
    @response.default(&@block)
    @response.default.should == @block
  end

  it "should accept a format symbol and block to publish" do
    @block = lambda { render :xml => object }
    @response.publish(:xml, &@block) 
    @response.publish_formats.should == [:xml]
    @response.publish_block.should == @block
  end
  
  it "should require a publish block if one is not already assigned" do
    lambda do
      @response.publish(:json)
    end.should raise_error
  end
  
  it "should accept multiple formats to publish" do
    @response.publish(:xml, :json) { render format_symbol => object }
    @response.publish_formats.should == [:xml, :json]
  end
  
  it "should add a new format to publish" do
    @response.publish(:xml) { render format_symbol => object }
    @response.publish_formats.should == [:xml]
    @response.publish(:json)
    @response.publish_formats.should == [:xml, :json]
  end
  
  it "should accept an arbitrary format block" do
    @block = lambda { render :template => "foo" }
    @response.iphone(&@block) 
    @response.blocks[:iphone].should == @block
  end

  it "should accept an arbitrary format without a block" do
    @response.iphone
    @response.each_format.should == [:iphone]
  end
  
  describe "prepared with some formats" do
    before :each do
      @responder = double("responder")
      @pblock = lambda { 'foo' }
      @response.publish(:xml, :json, &@pblock)
      @iblock = lambda { 'iphone' }
      @popblock = lambda { 'popup' }
      @response.iphone(&@iblock)
      @response.popup(&@popblock)
    end
    
    it "should iterate over the publish formats" do
      expect(@responder).to receive(:xml) {|a| a == @pblock}.once.ordered
      expect(@responder).to receive(:json) {|a| a == @pblock}.once.ordered
      @response.each_published do |format, block|
        @responder.send(format, &@block)
      end
    end

    it "should iterate over the regular formats" do
      expect(@responder).to receive(:iphone) {|a| a == @iblock}.once.ordered
      expect(@responder).to receive(:popup) {|a| a == @popblock}.once.ordered
      @response.each_format do |format, block|
        @responder.send(format, &@block)
      end
    end
  end
end