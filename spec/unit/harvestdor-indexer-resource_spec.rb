# frozen_string_literal: true

require 'spec_helper'

describe Harvestdor::Indexer::Resource do

  subject { resource }

  before(:all) do
    VCR.use_cassette('before_all_call') do
      @config_yml_path = File.join(File.dirname(__FILE__), '..', 'config', 'ap.yml')
      require 'yaml'
      @config = YAML.load_file(@config_yml_path)
      @fake_druid = 'oo000oo0000'

      @indexer = Harvestdor::Indexer.new(@config)
      @hdor_client = @indexer.send(:harvestdor_client)
      @whitelist_path = File.join(File.dirname(__FILE__), '../config/ap_whitelist.txt')
    end
  end

  let :resource do
    described_class.new(@indexer, @fake_druid)
  end

  let(:blank_public_xml) { Nokogiri::XML::Document.new }

  describe '#exists?' do
    it 'exists if the public xml is present and available' do
      allow(subject).to receive(:public_xml).and_return(blank_public_xml)
      expect(subject).to exist
    end

    it 'does not exist if the public xml is empty' do
      allow(subject).to receive(:public_xml).and_raise Harvestdor::Errors::MissingPurlPage
      expect(subject).not_to exist
    end

    it 'does not exist if the purl is missing' do
      allow(subject).to receive(:public_xml).and_raise Harvestdor::Errors::MissingPurlPage
      expect(subject).not_to exist
    end
  end

  describe '#items' do
    context 'for a regular item' do
      before do
        allow(subject).to receive(:collection?).and_return(false)
      end

      it 'is empty if it is not a collection' do
        expect(subject.items).to be_empty
      end
    end

    context 'for a collection' do
      before do
        allow(subject).to receive(:collection?).and_return(true)
        allow(subject).to receive(:items_druids).and_return %w[oo000oo0001 oo000oo0002]
      end

      it 'enumerates the items in the collection' do
        expect(subject.items.count).to eq 2

        child = subject.items.first
        expect(child.druid).to eq 'oo000oo0001'
      end

      it 'estimates the size of the enumerator without instantiating objects' do
        expect(described_class).not_to receive(:new)
        expect(subject.items.size).to eq 2
      end
    end
  end

  context 'smods_rec method' do
    before(:all) do
      @ns_decl = "xmlns='#{Mods::MODS_NS}'"
      @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
      @ng_mods_xml = Nokogiri::XML(@mods_xml)
    end

    it 'calls mods method on harvestdor_client' do
      expect(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      resource.smods_rec
    end

    it 'returns Stanford::Mods::Record object' do
      expect(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      expect(resource.smods_rec).to be_an_instance_of(Stanford::Mods::Record)
    end

    it 'raises exception if MODS xml for the druid is empty' do
      allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}/>"))
      expect { resource.smods_rec }.to raise_error(RuntimeError, Regexp.new("^Empty MODS metadata for #{@fake_druid}: <"))
    end

    it 'raises exception if there is no MODS xml for the druid' do
      VCR.use_cassette('exception_no_MODS_call') do
        expect { resource.smods_rec }.to raise_error(Harvestdor::Errors::MissingMods)
      end
    end
  end

  context 'public_xml related methods' do
    before(:all) do
      @id_md_xml = "<identityMetadata><objectId>druid:#{@fake_druid}</objectId></identityMetadata>"
      @cntnt_md_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'>foo</contentMetadata>"
      @rights_md_xml = '<rightsMetadata><access type="discover"><machine><world>bar</world></machine></access></rightsMetadata>'
      @rdf_xml = "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'><rdf:Description rdf:about=\"info:fedora/druid:#{@fake_druid}\">relationship!</rdf:Description></rdf:RDF>"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@id_md_xml}#{@cntnt_md_xml}#{@rights_md_xml}#{@rdf_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end

    describe '#public_xml' do
      it 'calls public_xml method on harvestdor_client' do
        expect(@hdor_client).to receive(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
        resource.public_xml
      end

      it 'retrieves entire public xml as a Nokogiri::XML::Document' do
        expect(@hdor_client).to receive(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
        px = resource.public_xml
        expect(px).to be_kind_of(Nokogiri::XML::Document)
        expect(px.root.name).to eq('publicObject')
        expect(px.root.attributes['id'].text).to eq("druid:#{@fake_druid}")
      end
    end

    describe '#content_metadata' do
      it 'returns a Nokogiri::XML::Document derived from the public xml if a druid is passed' do
        allow(Harvestdor).to receive(:public_xml).with(@fake_druid, @indexer.config.harvestdor.purl).and_return(@ng_pub_xml)
        cm = resource.content_metadata
        expect(cm).to be_kind_of(Nokogiri::XML::Document)
        expect(cm.root).not_to eq(nil)
        expect(cm.root.name).to eq('contentMetadata')
        expect(cm.root.attributes['objectId'].text).to eq(@fake_druid)
        expect(cm.root.text.strip).to eq('foo')
      end
    end

    describe '#identity_metadata' do
      it 'returns a Nokogiri::XML::Document derived from the public xml if a druid is passed' do
        allow(Harvestdor).to receive(:public_xml).with(@fake_druid, @indexer.config.harvestdor.purl).and_return(@ng_pub_xml)
        im = resource.identity_metadata
        expect(im).to be_kind_of(Nokogiri::XML::Document)
        expect(im.root).not_to eq(nil)
        expect(im.root.name).to eq('identityMetadata')
        expect(im.root.text.strip).to eq("druid:#{@fake_druid}")
      end
    end

    describe '#rights_metadata' do
      it 'returns a Nokogiri::XML::Document derived from the public xml if a druid is passed' do
        allow(Harvestdor).to receive(:public_xml).with(@fake_druid, @indexer.config.harvestdor.purl).and_return(@ng_pub_xml)
        im = resource.rights_metadata
        expect(im).to be_kind_of(Nokogiri::XML::Document)
        expect(im.root).not_to eq(nil)
        expect(im.root.name).to eq('rightsMetadata')
        expect(im.root.text.strip).to eq('bar')
      end
    end

    describe '#rdf' do
      it 'returns a Nokogiri::XML::Document derived from the public xml if a druid is passed' do
        allow(Harvestdor).to receive(:public_xml).with(@fake_druid, @indexer.config.harvestdor.purl).and_return(@ng_pub_xml)
        im = resource.rdf
        expect(im).to be_kind_of(Nokogiri::XML::Document)
        expect(im.root).not_to eq(nil)
        expect(im.root.name).to eq('RDF')
        expect(im.root.text.strip).to eq('relationship!')
      end
    end

    describe '#public_xml_or_druid' do
      it 'returns the public_xml, if the public_xml has been loaded' do
        allow(resource).to receive(:public_xml?).and_return(true)
        allow(resource).to receive(:public_xml).and_return(double)
        expect(resource.public_xml_or_druid).to eq resource.public_xml
      end

      it 'returns the druid, if the public_xml has not been loaded' do
        allow(resource).to receive(:public_xml?).and_return(false)
        expect(resource.public_xml_or_druid).to eq @fake_druid
      end
    end

    describe '#identity_md_obj_label' do
      it 'extracts the objectLabel from the identity metadata' do
        allow(resource).to receive(:identity_metadata).and_return(Nokogiri::XML('<identityMetadata><objectLabel>label</objectLabel></identityMetadata>'))
        expect(resource.identity_md_obj_label).to eq 'label'
      end
    end

    describe '#collections' do
      it 'extracts the collection this resource is a member of and return Resource objects for those collections' do
        allow(resource).to receive(:public_xml).and_return(Nokogiri::XML(<<~EOF)
          <publicObject>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
              <rdf:Description>
                <fedora:isMemberOfCollection rdf:resource="some:druid" />
              </rdf:Description>
            </rdf:RDF>
          </publicObject>
        EOF
                                                          )

        expect(resource.collections.length).to eq 1
        expect(resource.collections.first.druid).to eq 'some:druid'
        expect(resource.collections.first.indexer).to eq resource.indexer
      end
    end
  end

end
