require_relative '../lib/nagios'
require_relative 'spec_helper'

describe "Configuration" do 

  before { 
    @cfg = Nagios::Config.new ::TEST[:nagios_cfg]
  }

  context "nagios.cfg" do

    it { File.should exist @cfg.path }
    
    it "should be parseable" do
      lambda { @cfg.parse }.should_not raise_error
    end

    context "parsing nagios.cfg file" do 

      before { @cfg.parse }
      
      it "should have PATH to objects file" do 
        @cfg.object_cache_file.should be_a_kind_of String 
      end
      
      it "should have PATH to status file" do
        @cfg.status_file.should be_a_kind_of String 
      end

    end # parsing nagios.cfg file
  end # nagios.cfg
  
  context "data files" do 
    before { @cfg.parse }
    
    context Nagios::Status do

      context "OOP style" do
        subject { Nagios::Status.new( ::TEST[:status_file]  || @cfg.status_file ) }
        
        it { File.should exist( subject.path ) }
        
        it "should be parseable" do
          lambda { subject.parse }.should_not raise_error
        end
      end

      context "using parameter for parse method" do
        subject { Nagios::Status.new() }
        
        it { File.should exist( (::TEST[:status_file]  || @cfg.status_file) ) }
        
        it "should be parseable" do
          lambda { subject.parse(::TEST[:status_file]  || @cfg.status_file) }.should_not raise_error
        end

        it "should fail without a filename" do
          lambda { subject.parse() }.should raise_error
        end

      end

    end # Nagios::Status


    context Nagios::Objects do

      subject {  Nagios::Objects.new( ::TEST[:object_cache_file] || @cfg.object_cache_file) }

      it { File.should exist subject.path }
      
      it "should be parseable" do
        lambda { subject.parse }.should_not raise_error
      end
    end # Nagios::Objects

  end # data files

end
