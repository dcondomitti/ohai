#
# Author:: Tim Dysinger (<tim@dysinger.net>)
# Author:: Christopher Brown (cb@opscode.com)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDIT"Net::HTTP Response"NS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'open-uri'

describe Ohai::System, "plugin ec2" do
  before(:each) do
    @ohai = Ohai::System.new
    @plugin = Ohai::DSL::Plugin.new(@ohai, File.join(PLUGIN_PATH, "ec2.rb"))
    @plugin.stub!(:require_plugin).and_return(true)
    @plugin[:network] = {:interfaces => {:eth0 => {} } }
  end

  shared_examples_for "!ec2" do
    it "should NOT attempt to fetch the ec2 metadata" do
      @plugin.should_not_receive(:http_client)
      @plugin.run
    end
  end

  shared_examples_for "ec2" do
    before(:each) do
      @http_client = mock("Net::HTTP client")
      @plugin.stub!(:http_client).and_return(@http_client)

      @http_client.should_receive(:get).
        with("/2008-02-01/meta-data/").
        and_return(mock("Net::HTTP Response", :body => "instance_type\nami_id\nsecurity-groups"))
      @http_client.should_receive(:get).
        with("/2008-02-01/meta-data/instance_type").
        and_return(mock("Net::HTTP Response", :body => "c1.medium"))
      @http_client.should_receive(:get).
        with("/2008-02-01/meta-data/ami_id").
        and_return(mock("Net::HTTP Response", :body => "ami-5d2dc934"))
      @http_client.should_receive(:get).
        with("/2008-02-01/meta-data/security-groups").
        and_return(mock("Net::HTTP Response", :body => "group1\ngroup2"))
      @http_client.should_receive(:get).
        with("/2008-02-01/user-data/").
        and_return(mock("Net::HTTP Response", :body => "By the pricking of my thumb...", :code => "200"))
    end

    it "should recursively fetch all the ec2 metadata" do
      IO.stub!(:select).and_return([[],[1],[]])
      t = mock("connection")
      t.stub!(:connect_nonblock).and_raise(Errno::EINPROGRESS)
      Socket.stub!(:new).and_return(t)
      @plugin.run
      @plugin[:ec2].should_not be_nil
      @plugin[:ec2]['instance_type'].should == "c1.medium"
      @plugin[:ec2]['ami_id'].should == "ami-5d2dc934"
      @plugin[:ec2]['security_groups'].should eql ['group1', 'group2']
    end
  end

  describe "with ec2 mac and metadata address connected" do
    it_should_behave_like "ec2"

    before(:each) do
      IO.stub!(:select).and_return([[],[1],[]])
      @plugin[:network][:interfaces][:eth0][:arp] = {"169.254.1.0"=>"fe:ff:ff:ff:ff:ff"}
    end
  end

  describe "without ec2 mac and metadata address connected" do
    it_should_behave_like "!ec2"

    before(:each) do
      @plugin[:network][:interfaces][:eth0][:arp] = {"169.254.1.0"=>"00:50:56:c0:00:08"}
    end
  end
  
  describe "with ec2 cloud file" do
    it_should_behave_like "ec2"

    before(:each) do
      File.stub!(:exist?).with('/etc/chef/ohai/hints/ec2.json').and_return(true)
      File.stub!(:read).with('/etc/chef/ohai/hints/ec2.json').and_return('')
      File.stub!(:exist?).with('C:\chef\ohai\hints/ec2.json').and_return(true)
      File.stub!(:read).with('C:\chef\ohai\hints/ec2.json').and_return('')
    end
  end

  describe "without cloud file" do
    it_should_behave_like "!ec2"
  
    before(:each) do
      File.stub!(:exist?).with('/etc/chef/ohai/hints/ec2.json').and_return(false)
      File.stub!(:exist?).with('C:\chef\ohai\hints/ec2.json').and_return(false)
    end
  end
  
  describe "with rackspace cloud file" do
    it_should_behave_like "!ec2"
  
    before(:each) do
      File.stub!(:exist?).with('/etc/chef/ohai/hints/ec2.json').and_return(false)
      File.stub!(:exist?).with('C:\chef\ohai\hints/ec2.json').and_return(false)

      File.stub!(:exist?).with('/etc/chef/ohai/hints/rackspace.json').and_return(true)
      File.stub!(:read).with('/etc/chef/ohai/hints/rackspace.json').and_return('')
      File.stub!(:exist?).with('C:\chef\ohai\hints/rackspace.json').and_return(true)
      File.stub!(:read).with('C:\chef\ohai\hints/rackspace.json').and_return('')
    end
  end
  
end
