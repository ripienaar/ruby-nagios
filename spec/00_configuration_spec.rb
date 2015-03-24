require_relative '../lib/nagios'
require_relative 'spec_helper'

describe "Configuration" do 

  before { 
    @cfg = Nagios::Config.new ::TEST[:nagios_cfg]
  }

  context "nagios.cfg" do

    it { expect(File).to exist @cfg.path }
    
    it "should be parseable" do
      expect { @cfg.parse }.not_to raise_error
    end

    context "parsing nagios.cfg file" do 

      before { @cfg.parse }
      
      it "should have PATH to objects file" do 
        expect(@cfg.object_cache_file).to be_a_kind_of String
      end
      
      it "should have PATH to status file" do
        expect(@cfg.status_file).to be_a_kind_of String
      end

    end # parsing nagios.cfg file
  end # nagios.cfg
  
  context "data files" do 
    before { @cfg.parse }
    
    context Nagios::Status do

      context "OOP style" do
        subject { Nagios::Status.new( ::TEST[:status_file]  || @cfg.status_file ) }
        
        it { expect(File).to exist( subject.path ) }
        
        it "should be parseable" do
          expect { subject.parse }.not_to raise_error
        end
      end

      context "using parameter for parse method" do
        subject { Nagios::Status.new() }
        
        it { expect(File).to exist( (::TEST[:status_file]  || @cfg.status_file) ) }
        
        it "should be parseable" do
          expect { subject.parse(::TEST[:status_file]  || @cfg.status_file) }.not_to raise_error
        end

        it "should fail without a filename" do
          expect { subject.parse() }.to raise_error
        end

      end

    end # Nagios::Status


    context Nagios::Objects do

      subject {  Nagios::Objects.new( ::TEST[:object_cache_file] || @cfg.object_cache_file) }

      it { expect(File).to exist subject.path }
      
      it "should be parseable" do
        expect { subject.parse }.not_to raise_error
      end
    end # Nagios::Objects

  end # data files

end
